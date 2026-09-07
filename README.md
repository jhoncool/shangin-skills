# shangin-skills

## Deep Code Review

Плагин для глубокого ревью локальных изменений, GitHub pull request и удалённых веток. Он устанавливает два скилла:

- `deep-code-review` — ревью локальных изменений или заданного диапазона коммитов.
- `github-pr-worktree-review` — ревью GitHub PR или удалённой ветки в изолированном Git worktree.

## Требования

| Компонент | Статус |
|---|---|
| [Git](https://git-scm.com/downloads) | Обязателен |
| [GitHub CLI (`gh`)](https://cli.github.com/) и авторизация GitHub | Рекомендуются для полного PR-контекста, статусов проверок и автоматического определения base-ветки |
| Matt Pocock `code-review` | Уже включён в плагин; отдельная установка через `npx skills` не нужна |
| `deep-code-review` для Worktree Review | Уже включён в тот же плагин |
| `datalens-team-skills:startrek` | Опционален; добавляет описание и комментарии из Yandex Tracker |

Проверьте системные зависимости:

```bash
git --version
gh --version
gh auth status
```

Если GitHub CLI установлен, но ещё не авторизован, выполните `gh auth login --hostname github.com`.

Без `gh` Worktree Review может работать в ограниченном git-only режиме: передайте полный URL PR и явно назовите base-ветку.

При запуске скиллы сами проверяют обязательные зависимости и целостность комплекта. Они не устанавливают системные программы автоматически: при отсутствии `git` работа остановится с инструкцией, а отсутствие `gh` включит git-only режим.

## Установка

Добавьте Git marketplace и установите плагин:

```bash
codex plugin marketplace add https://github.com/jhoncool/shangin-skills.git --ref main
codex plugin add deep-code-review@shangin-skills
```

Если marketplace уже зарегистрирован, первую команду повторять не нужно. Проверить его можно так:

```bash
codex plugin marketplace list
```

Для Tracker-контекста установите доступный вашей среде плагин со скиллом Startrek. В текущем Yandex marketplace это:

```bash
codex plugin add datalens-team-skills@datalens-marketplace
```

После установки откройте новую задачу Codex, чтобы она получила обновлённый каталог скиллов.

## Локальное ревью

Пример ревью незакоммиченных изменений:

```text
Используй $deep-code-review и проверь все незакоммиченные изменения.
```

Пример ревью ветки относительно `main` с контекстом Tracker:

```text
Используй $deep-code-review. Проверь изменения от merge-base с origin/main до HEAD. Учти требования DATALENS-1234.
```

Для нетривиального изменения скилл выполняет пять направлений ревью: Correctness, Integration, Resilience, Standards и Spec. Замечания получают стабильные номера `#1`, `#2`, …, поэтому после отчёта можно написать:

```text
Исправь #1, #3 и #6. Для #2 используй предложенный мной вариант.
```

## Ревью GitHub PR или удалённой ветки

Пример PR:

```text
Используй $github-pr-worktree-review и проведи глубокое ревью https://github.com/owner/repository/pull/123.
```

Пример удалённой ветки:

```text
Используй $github-pr-worktree-review. Проверь ветку origin/feature-branch относительно origin/main.
```

Пример без доступного `gh`:

```text
Используй $github-pr-worktree-review для https://github.com/owner/repository/pull/123. gh недоступен; используй origin/main как base-ветку.
```

Если в запросе, PR, имени ветки или сообщениях коммитов найден ключ Yandex Tracker, скилл использует доступный Startrek-контекст автоматически.

---

**Агенту, который изменяет или выпускает плагины:** перед началом работы обязательно прочитать [DEVELOPMENT.md](DEVELOPMENT.md).
