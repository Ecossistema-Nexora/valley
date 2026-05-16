#!/usr/bin/env python3
# PROPOSITO: Servidor WebSocket leve para rastreamento Valley em tempo real.
# CONTEXTO: MVP Marketplace local com courier -> backend -> usuario/merchant.
# REGRAS: Sem dependencias externas, sem segredos em log e com persistencia em tmp/runtime.

from __future__ import annotations

import argparse
import asyncio
import base64
import hashlib
import json
import struct
import time
import uuid
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
RUNTIME_DIR = ROOT / "tmp" / "runtime"
EVENTS_PATH = RUNTIME_DIR / "valley-realtime-tracking-events.jsonl"
STATE_PATH = RUNTIME_DIR / "valley-realtime-tracking-state.json"
WS_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def append_jsonl(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(payload, ensure_ascii=False, sort_keys=True))
        handle.write("\n")


def write_state(sessions: dict[str, dict[str, Any]]) -> None:
    STATE_PATH.parent.mkdir(parents=True, exist_ok=True)
    tmp = STATE_PATH.with_suffix(".tmp")
    payload = {
        "service": "valley-realtime-tracking-ws",
        "status": "ok",
        "generated_at_utc": utc_now_iso(),
        "sessions": sessions,
    }
    tmp.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    tmp.replace(STATE_PATH)


@dataclass
class Client:
    id: str
    writer: asyncio.StreamWriter
    subscriptions: set[str] = field(default_factory=set)
    role: str = "unknown"


class TrackingHub:
    def __init__(self) -> None:
        self.clients: dict[str, Client] = {}
        self.sessions: dict[str, dict[str, Any]] = {}

    async def register(self, writer: asyncio.StreamWriter) -> Client:
        client = Client(id=str(uuid.uuid4()), writer=writer)
        self.clients[client.id] = client
        await self.send(client, {"type": "hello", "client_id": client.id, "service": "valley-realtime-tracking-ws"})
        return client

    def unregister(self, client: Client) -> None:
        self.clients.pop(client.id, None)

    async def handle_message(self, client: Client, message: dict[str, Any]) -> None:
        message_type = str(message.get("type") or "").strip()
        order_id = str(message.get("order_id") or message.get("tracking_code") or "default").strip() or "default"
        if message_type in {"customer.subscribe", "merchant.subscribe"}:
            client.role = "merchant" if message_type.startswith("merchant") else "customer"
            client.subscriptions.add(order_id)
            await self.send(client, {"type": "tracking.snapshot", "order_id": order_id, "payload": self.sessions.get(order_id, {})})
            return

        if message_type == "tracking.stop":
            self.sessions.pop(order_id, None)
            write_state(self.sessions)
            await self.broadcast(order_id, {"type": "tracking.stopped", "order_id": order_id, "received_at_utc": utc_now_iso()})
            return

        if message_type == "courier.telemetry":
            client.role = "courier"
            client.subscriptions.add(order_id)
            event = self.normalize_telemetry(order_id, message)
            self.sessions[order_id] = event
            append_jsonl(EVENTS_PATH, event)
            write_state(self.sessions)
            await self.broadcast(order_id, {"type": "tracking.update", "order_id": order_id, "payload": event})
            return

        await self.send(client, {"type": "error", "detail": f"Unsupported message type: {message_type}"})

    def normalize_telemetry(self, order_id: str, message: dict[str, Any]) -> dict[str, Any]:
        return {
            "event_id": str(uuid.uuid4()),
            "service": "valley-realtime-tracking-ws",
            "type": "courier.telemetry",
            "order_id": order_id,
            "tracking_code": str(message.get("tracking_code") or order_id),
            "courier_id": str(message.get("courier_id") or ""),
            "merchant_id": str(message.get("merchant_id") or ""),
            "latitude": float(message.get("latitude") or 0),
            "longitude": float(message.get("longitude") or 0),
            "speed_mps": message.get("speed_mps"),
            "heading_degrees": message.get("heading_degrees"),
            "accuracy_meters": message.get("accuracy_meters"),
            "delivery_status": str(message.get("delivery_status") or "IN_TRANSIT"),
            "recorded_at_utc": str(message.get("recorded_at_utc") or utc_now_iso()),
            "received_at_utc": utc_now_iso(),
        }

    async def broadcast(self, order_id: str, payload: dict[str, Any]) -> None:
        dead: list[Client] = []
        for client in list(self.clients.values()):
            if order_id not in client.subscriptions and "*" not in client.subscriptions:
                continue
            try:
                await self.send(client, payload)
            except (ConnectionError, OSError):
                dead.append(client)
        for client in dead:
            self.unregister(client)

    async def send(self, client: Client, payload: dict[str, Any]) -> None:
        data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        client.writer.write(encode_ws_frame(data))
        await client.writer.drain()


def encode_ws_frame(payload: bytes) -> bytes:
    header = bytearray([0x81])
    length = len(payload)
    if length < 126:
        header.append(length)
    elif length <= 0xFFFF:
        header.append(126)
        header.extend(struct.pack("!H", length))
    else:
        header.append(127)
        header.extend(struct.pack("!Q", length))
    return bytes(header) + payload


async def read_ws_frame(reader: asyncio.StreamReader) -> bytes | None:
    first = await reader.readexactly(2)
    opcode = first[0] & 0x0F
    if opcode == 0x8:
        return None
    masked = (first[1] & 0x80) != 0
    length = first[1] & 0x7F
    if length == 126:
        length = struct.unpack("!H", await reader.readexactly(2))[0]
    elif length == 127:
        length = struct.unpack("!Q", await reader.readexactly(8))[0]
    mask = await reader.readexactly(4) if masked else b""
    payload = await reader.readexactly(length)
    if masked:
        payload = bytes(byte ^ mask[index % 4] for index, byte in enumerate(payload))
    return payload


async def handshake(reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> bool:
    request = await reader.readuntil(b"\r\n\r\n")
    text = request.decode("utf-8", errors="ignore")
    headers: dict[str, str] = {}
    for line in text.split("\r\n")[1:]:
        if ":" in line:
            key, value = line.split(":", 1)
            headers[key.strip().lower()] = value.strip()
    key = headers.get("sec-websocket-key")
    if not key:
        writer.write(b"HTTP/1.1 400 Bad Request\r\nConnection: close\r\n\r\n")
        await writer.drain()
        return False
    accept = base64.b64encode(hashlib.sha1((key + WS_GUID).encode("ascii")).digest()).decode("ascii")
    response = (
        "HTTP/1.1 101 Switching Protocols\r\n"
        "Upgrade: websocket\r\n"
        "Connection: Upgrade\r\n"
        f"Sec-WebSocket-Accept: {accept}\r\n"
        "\r\n"
    )
    writer.write(response.encode("ascii"))
    await writer.drain()
    return True


async def serve_client(reader: asyncio.StreamReader, writer: asyncio.StreamWriter, hub: TrackingHub) -> None:
    if not await handshake(reader, writer):
        writer.close()
        await writer.wait_closed()
        return
    client = await hub.register(writer)
    try:
        while True:
            frame = await read_ws_frame(reader)
            if frame is None:
                break
            try:
                payload = json.loads(frame.decode("utf-8"))
            except json.JSONDecodeError:
                await hub.send(client, {"type": "error", "detail": "Invalid JSON payload"})
                continue
            if isinstance(payload, dict):
                await hub.handle_message(client, payload)
    except (asyncio.IncompleteReadError, ConnectionError, OSError):
        pass
    finally:
        hub.unregister(client)
        writer.close()
        try:
            await writer.wait_closed()
        except OSError:
            pass


async def main_async(host: str, port: int) -> None:
    hub = TrackingHub()
    RUNTIME_DIR.mkdir(parents=True, exist_ok=True)
    write_state(hub.sessions)
    server = await asyncio.start_server(lambda r, w: serve_client(r, w, hub), host, port)
    print(json.dumps({"status": "ok", "service": "valley-realtime-tracking-ws", "url": f"ws://{host}:{port}/ws/tracking", "started_at_utc": utc_now_iso()}))
    async with server:
        await server.serve_forever()


def main() -> int:
    parser = argparse.ArgumentParser(description="Valley realtime tracking WebSocket server")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8765)
    args = parser.parse_args()
    try:
        asyncio.run(main_async(args.host, args.port))
    except KeyboardInterrupt:
        return 0
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

