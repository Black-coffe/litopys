# Brief: correction-evidence

**Date:** 2026-09-30
**Tier:** 2 - one module (the plugin: journal hook, `bin/litopys`, the distiller agent), three independent changes
**Source study:** VULYK `docs/specs/hindsight-memory/report.md` (vulyk 4aa0fb3), items C1, C2, C3; VULYK v0.23.0 shipped the VULYK half

## Request (verbatim)

> Две задачи остаются на потом, я записал их в память проекта, чтобы следующая сессия их не потеряла:
> 1. litopys. В журнале отделить служебные сообщения от ваших слов (C1). Принимать в хронику только цитаты, которые дословно есть в журнале (C2). Добавить команду litopys corrections, а после неё — счётчик в /vulyk-evolve (C3).
> 2. YouTube_AI после выпуска v0.23: прописать paths: девяти карточкам и убрать claude -p из SessionEnd. Далее сделай вот эти две задачи, как закончишь с предыдущей.

Owner's earlier answer to «Интегрируем в VULYK то, что приняла редколлегия?», 2026-09-29:

> Весь пакет (Рекомендую)

Item 2 (YouTube_AI) is a separate task in that repo. The `/vulyk-evolve` counter is a VULYK change made after this spec ships.

## Answers

1. Цитаты — И в решениях, и в поправках (Рекомендую): Строка в `## Decisions` может заканчиваться «цитатой», и новая секция `## Corrections` — ваши поправки. Именно Corrections кормит `litopys corrections` (C3), а цитата в решении даёт recall пруф «что именно вы сказали». Сейчас обе записи хроники — пересказ без цитат.
2. Словарь — Передаёт VULYK (Рекомендую): `--lexicon <файл>`: VULYK отдаёт тот же словарь, что у его хука defect-intake, — один источник, без расхождения. litopys остаётся языконезависимым (работает и в не-кодовых проектах); без флага читает только `## Corrections` из записей.
3. Требования — Верно, покажи план (Рекомендую): Три пункта как есть; стандартный стоп Tier 2 на утверждение — формат записи хроники меняется (пятая секция), это стоит одного взгляда.

## Asks

1. журнал пишет служебные вставки (отчёты субагентов, system-reminder, сообщения других сессий, вставленный текст) отдельным блоком `## notice`, не как ваши слова
2. дистиллятор пишет «цитаты» в решениях и секцию `## Corrections`, а `distill record` отказывает, если цитаты нет дословно в ваших словах журнала
3. команда `litopys corrections [--since] [--lexicon]` печатает «дата · сессия · «цитата»»
