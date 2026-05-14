#!/usr/bin/env python3
"""
GERADOR DE MANUAL PDF - VALLEY
==============================
PROPOSITO: Converter a documentacao viva em Markdown (MANUAL_ONLINE) para PDF executivo.
CONTEXTO: Utilizado para compartilhamento com stakeholders e leitura offline da arquitetura tecnica.
REGRAS: Renderizar com reportlab, preservar identidade visual Valley e gravar o artefato em output/pdf.

Propósito: Converter a documentação viva em Markdown (MANUAL_ONLINE) para um formato PDF executivo.
Contexto: Utilizado para compartilhamento com stakeholders e leitura offline da arquitetura técnica.
Regras:
1. Utiliza a biblioteca reportlab para renderização.
2. Mantém a identidade visual Valley (Cores e Fontes específicas).
"""

# pathlib fornece caminhos portaveis para localizar o projeto.
from pathlib import Path

# html.escape protege caracteres especiais antes de enviar texto ao Paragraph.
from html import escape

# reportlab cria o PDF tecnico sem depender de navegador ou servidor externo.
from reportlab.lib import colors

# A4 define o tamanho de pagina padrao para documentacao executiva.
from reportlab.lib.pagesizes import A4

# getSampleStyleSheet entrega estilos base para headings e corpo de texto.
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet

# inch facilita margens e espaçamentos com unidade legivel.
from reportlab.lib.units import inch

# SimpleDocTemplate, Paragraph, Spacer e PageBreak constroem o fluxo do PDF.
from reportlab.platypus import PageBreak, Paragraph, SimpleDocTemplate, Spacer


# ROOT aponta para a raiz da worktree Valley, um nivel acima da pasta scripts.
ROOT = Path(__file__).resolve().parents[1]

# MANUAL_DIR guarda todos os arquivos Markdown que compoem o Manual Online vivo.
MANUAL_DIR = ROOT / 'MANUAL_ONLINE'

# SOURCE_MARKDOWN e o indice principal que sempre abre a documentacao.
SOURCE_MARKDOWN = MANUAL_DIR / 'README.md'

# OUTPUT_PDF e a vertente PDF sempre regenerada a partir do Markdown.
OUTPUT_PDF = ROOT / 'output' / 'pdf' / 'VALLEY_MANUAL_ONLINE.pdf'


# build_styles cria estilos consistentes para titulo, secoes, texto e codigo.
def build_styles():
    # styles inicia com os estilos padrao do ReportLab.
    styles = getSampleStyleSheet()

    # styles['Title'] recebe identidade visual simples e forte para a capa.
    styles['Title'].fontName = 'Helvetica-Bold'
    styles['Title'].fontSize = 22
    styles['Title'].leading = 28
    styles['Title'].textColor = colors.HexColor('#12312B')
    styles['Title'].spaceAfter = 18

    # Heading1 representa secoes principais do manual.
    styles['Heading1'].fontName = 'Helvetica-Bold'
    styles['Heading1'].fontSize = 16
    styles['Heading1'].leading = 20
    styles['Heading1'].textColor = colors.HexColor('#16463D')
    styles['Heading1'].spaceBefore = 14
    styles['Heading1'].spaceAfter = 8

    # Heading2 representa subsecoes tecnicas quando existirem.
    styles['Heading2'].fontName = 'Helvetica-Bold'
    styles['Heading2'].fontSize = 13
    styles['Heading2'].leading = 17
    styles['Heading2'].textColor = colors.HexColor('#245B4F')
    styles['Heading2'].spaceBefore = 10
    styles['Heading2'].spaceAfter = 6

    # BodyText e usado para paragrafos comuns em portugues simples.
    styles['BodyText'].fontName = 'Helvetica'
    styles['BodyText'].fontSize = 10
    styles['BodyText'].leading = 14
    styles['BodyText'].textColor = colors.HexColor('#1E2423')
    styles['BodyText'].spaceAfter = 6

    # CodeStyle diferencia comandos e trechos tecnicos como Markdown code blocks.
    styles.add(ParagraphStyle(
        # name identifica o estilo customizado para blocos de codigo.
        name='CodeStyle',
        # fontName usa Helvetica monospaced-like nao disponivel; Courier e o padrao tecnico.
        fontName='Courier',
        # fontSize menor preserva linhas de comando dentro da largura da pagina.
        fontSize=8,
        # leading controla espaco vertical entre linhas de codigo.
        leading=10,
        # textColor usa verde escuro para manter identidade Valley.
        textColor=colors.HexColor('#0F2A24'),
        # backColor cria contraste leve para leitura tecnica.
        backColor=colors.HexColor('#EEF5F1'),
        # borderPadding cria respiro interno no bloco de codigo.
        borderPadding=6,
        # spaceAfter separa o bloco do proximo paragrafo.
        spaceAfter=8,
    ))

    # Retorna o dicionario de estilos pronto para uso.
    return styles


# markdown_to_story transforma linhas Markdown em elementos ReportLab.
def markdown_to_story(markdown_text, styles):
    # story acumula os elementos que serao renderizados no PDF.
    story = []

    # in_code_block indica se o parser esta dentro de um bloco ```bash.
    in_code_block = False

    # code_lines acumula linhas de codigo ate fechar o bloco.
    code_lines = []

    # Adiciona uma capa simples com nome do projeto e finalidade.
    story.append(Paragraph('Manual Online - Valley Hybrid DB Bootstrap', styles['Title']))

    # Adiciona subtitulo tecnico para orientar leitores executivos e engenharia.
    story.append(Paragraph('Fonte viva em Markdown com vertente PDF derivada para schema PostgreSQL + MongoDB.', styles['BodyText']))

    # Insere quebra de pagina para separar capa do conteudo.
    story.append(PageBreak())

    # Percorre o Markdown linha por linha para manter estrutura previsivel.
    for raw_line in markdown_text.splitlines():
        # line preserva o conteudo sem quebra final.
        line = raw_line.rstrip()

        # Detecta abertura ou fechamento de code fence Markdown.
        if line.startswith('```'):
            # Se ja estava em bloco, fecha e envia para o PDF.
            if in_code_block:
                # escaped_code protege caracteres especiais dentro do bloco.
                escaped_code = '<br/>'.join(escape(code_line) for code_line in code_lines)
                # Paragraph renderiza o bloco tecnico com estilo CodeStyle.
                story.append(Paragraph(escaped_code or '&nbsp;', styles['CodeStyle']))
                # Limpa linhas acumuladas para o proximo bloco.
                code_lines = []
                # Marca saida do bloco de codigo.
                in_code_block = False
            else:
                # Marca entrada em bloco de codigo.
                in_code_block = True
            # Continua para a proxima linha sem renderizar a fence.
            continue

        # Dentro de bloco de codigo, apenas acumula texto bruto.
        if in_code_block:
            # Adiciona a linha ao buffer tecnico.
            code_lines.append(line)
            # Continua sem criar paragrafo comum.
            continue

        # Linhas vazias viram pequeno espaco vertical.
        if not line:
            # Spacer cria respiro visual entre secoes.
            story.append(Spacer(1, 0.08 * inch))
            # Continua para a proxima linha.
            continue

        # Heading nivel 1 vira titulo de secao.
        if line.startswith('# '):
            # Remove marcador Markdown e renderiza como titulo.
            story.append(Paragraph(escape(line[2:]), styles['Heading1']))
            # Continua para evitar renderizacao duplicada.
            continue

        # Heading nivel 2 vira subtitulo tecnico.
        if line.startswith('## '):
            # Remove marcador Markdown e renderiza como subtitulo.
            story.append(Paragraph(escape(line[3:]), styles['Heading1']))
            # Continua para evitar renderizacao duplicada.
            continue

        # Heading nivel 3 vira subtitulo menor.
        if line.startswith('### '):
            # Remove marcador Markdown e renderiza como Heading2.
            story.append(Paragraph(escape(line[4:]), styles['Heading2']))
            # Continua para evitar renderizacao duplicada.
            continue

        # Paragrafos comuns recebem escape para evitar XML invalido.
        story.append(Paragraph(escape(line), styles['BodyText']))

    # Se o arquivo terminar dentro de bloco de codigo, renderiza mesmo assim.
    if code_lines:
        # escaped_code protege caracteres especiais no bloco final.
        escaped_code = '<br/>'.join(escape(code_line) for code_line in code_lines)
        # Adiciona bloco final ao story.
        story.append(Paragraph(escaped_code, styles['CodeStyle']))

    # Retorna todos os elementos prontos para o build do PDF.
    return story


# collect_manual_markdown junta README e documentos auxiliares em uma unica fonte PDF.
def collect_manual_markdown():
    # Garante que o README exista antes de montar o manual consolidado.
    if not SOURCE_MARKDOWN.exists():
        # Erro claro para automacoes e operadores humanos.
        raise FileNotFoundError(f'Manual Markdown nao encontrado: {SOURCE_MARKDOWN}')

    # markdown_files inicia pelo README para manter capa e ordem de leitura.
    markdown_files = [SOURCE_MARKDOWN]

    # markdown_files recebe os demais documentos em ordem alfabetica previsivel.
    markdown_files.extend(
        # Cada arquivo .md complementar vira uma secao do PDF.
        path for path in sorted(MANUAL_DIR.glob('*.md'))
        # O README nao deve entrar duas vezes no PDF.
        if path.name != SOURCE_MARKDOWN.name
    )

    # sections acumula o conteudo bruto de cada Markdown com separadores claros.
    sections = []

    # Percorre todos os arquivos vivos do manual.
    for path in markdown_files:
        # Lemos em UTF-8 para preservar portugues do Brasil.
        content = path.read_text(encoding='utf-8')
        # Adiciona cabecalho tecnico de origem para rastreabilidade no PDF.
        sections.append(f'\\n\\n# Fonte: {path.relative_to(ROOT)}\\n\\n{content}')

    # Retorna um unico texto Markdown consolidado.
    return '\\n'.join(sections)


# main coordena leitura dos Markdowns, criacao de pasta e geracao do PDF.
def main():
    # Cria a pasta de saida do PDF se ainda nao existir.
    OUTPUT_PDF.parent.mkdir(parents=True, exist_ok=True)

    # Le todos os Markdowns vivos do Manual Online em uma fonte consolidada.
    markdown_text = collect_manual_markdown()

    # Monta estilos visuais do documento.
    styles = build_styles()

    # Converte Markdown simples em flowables do ReportLab.
    story = markdown_to_story(markdown_text, styles)

    # Cria o documento PDF com margens executivas.
    doc = SimpleDocTemplate(
        # filename aponta para o destino final do PDF.
        str(OUTPUT_PDF),
        # pagesize define A4 como padrao de documentacao.
        pagesize=A4,
        # rightMargin controla a margem direita.
        rightMargin=0.65 * inch,
        # leftMargin controla a margem esquerda.
        leftMargin=0.65 * inch,
        # topMargin controla a margem superior.
        topMargin=0.7 * inch,
        # bottomMargin controla a margem inferior.
        bottomMargin=0.7 * inch,
        # title grava metadado tecnico no PDF.
        title='Manual Online - Valley Hybrid DB Bootstrap',
        # author grava autoria operacional.
        author='Codex - Valley',
    )

    # build renderiza e grava o PDF final.
    doc.build(story)

    # Exibe caminho para logs de automacao.
    print(OUTPUT_PDF)


# Executa main apenas quando o script e chamado diretamente.
if __name__ == '__main__':
    # main inicia a geracao do manual PDF.
    main()
