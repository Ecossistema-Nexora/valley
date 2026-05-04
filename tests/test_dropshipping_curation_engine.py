import unittest

from scripts.import_dropshipping_eligible_products import (
    ConnectorRateLimiter,
    RateLimitPolicy,
    evaluate_candidate,
)


RULES = {
    "min_margin_pct": 22,
    "min_estimated_profit_brl": 18,
    "max_price_brl": 900,
    "min_stock": 10,
    "min_source_score": 60,
    "min_marketplace_advantage_pct": 10,
    "blocked_terms": ["arma", "replica"],
    "preferred_terms_ptbr": ["casa", "cozinha"],
}


def candidate(**overrides):
    payload = {
        "normalized_title": "organizador cozinha casa",
        "source_price_brl": 100.0,
        "stock": 80,
        "source_score": 72,
    }
    payload.update(overrides)
    return payload


class DropshippingCurationEngineTest(unittest.TestCase):
    def test_approve_when_no_competition_and_costs_are_viable(self):
        result = evaluate_candidate(candidate(), [], RULES)

        self.assertTrue(result["approved"])
        self.assertEqual(result["status"], "APPROVED_NO_COMPETITION")

    def test_approve_when_final_price_is_at_least_10_percent_below_lowest_competitor(self):
        result = evaluate_candidate(
            candidate(source_price_brl=100.0),
            [{"provider": "mercado_livre", "status": "ok", "min_price_brl": 150.0}],
            RULES,
        )

        self.assertTrue(result["approved"])
        self.assertEqual(result["status"], "APPROVED_PRICE_ADVANTAGE")
        self.assertEqual(result["target_price_brl"], 122.0)
        self.assertGreaterEqual(result["marketplace_advantage_pct"], 10)

    def test_reject_when_price_advantage_is_below_10_percent(self):
        result = evaluate_candidate(
            candidate(source_price_brl=120.0),
            [{"provider": "mercado_livre", "status": "ok", "min_price_brl": 150.0}],
            RULES,
        )

        self.assertFalse(result["approved"])
        self.assertEqual(result["status"], "REJECTED_PRICE_NOT_COMPETITIVE")
        self.assertIn("marketplace_advantage_below_minimum", result["rejection_reasons"])

    def test_reject_blocked_terms_before_publication(self):
        result = evaluate_candidate(candidate(normalized_title="replica acessorio"), [], RULES)

        self.assertFalse(result["approved"])
        self.assertEqual(result["status"], "REJECTED_COMPLIANCE")
        self.assertIn("blocked_term", result["rejection_reasons"])

    def test_rate_limiter_respects_retry_after(self):
        limiter = ConnectorRateLimiter(RateLimitPolicy("test", max_backoff_seconds=30))

        wait = limiter.after_failure(retry_after_seconds=7)

        self.assertEqual(wait, 7)

    def test_rate_limiter_opens_circuit_after_failures(self):
        limiter = ConnectorRateLimiter(
            RateLimitPolicy("test", circuit_breaker_failures=2, circuit_breaker_cooldown_seconds=60)
        )

        limiter.after_failure(retry_after_seconds=0)
        limiter.after_failure(retry_after_seconds=0)

        self.assertGreater(limiter.circuit_open_until, 0)


if __name__ == "__main__":
    unittest.main()
