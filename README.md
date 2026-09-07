# yandex-skills

Git-репозиторий с исходниками личных Codex-плагинов. Репозиторий одновременно является локальным Codex marketplace, поэтому в него можно добавлять несколько независимых плагинов и устанавливать их по имени.

## Структура

```text
.agents/plugins/marketplace.json  # каталог плагинов для Codex
plugins/
  deep-code-review/               # один самодостаточный плагин
requirements-dev.txt              # зависимости штатных валидаторов
scripts/
  bootstrap-dev.sh                # локальное окружение для проверок
  bump-plugin-version.sh          # новый cachebuster и валидация
  validate-marketplace.py         # целостность общего каталога
  validate-plugin.sh              # проверка каталога, манифеста и SKILL.md
```

Каждый новый плагин хранится в `plugins/<plugin-name>` и обязан содержать `.codex-plugin/plugin.json`. Запись с тем же именем добавляется в `.agents/plugins/marketplace.json`.

## Плагины

| Плагин | Назначение |
|---|---|
| `deep-code-review` | Глубокое ревью локальных изменений и GitHub PR; содержит скиллы `deep-code-review` и `github-pr-worktree-review`. |

## Первая установка из этого репозитория

На Mac подготовьте валидаторы, проверьте плагин и зарегистрируйте checkout как marketplace:

```bash
cd /Users/shangin/g/yandex-skills
./scripts/bootstrap-dev.sh
./scripts/validate-plugin.sh deep-code-review
codex plugin marketplace add "$PWD"
```

Если плагин ещё не установлен, добавьте его:

```bash
codex plugin add deep-code-review@yandex-skills
```

Если `deep-code-review@personal` уже установлен, держите активной только одну копию плагина. После регистрации `yandex-skills` перенесите установку:

```bash
codex plugin remove deep-code-review@personal
codex plugin add deep-code-review@yandex-skills
```

На удалённом сервере один раз клонируйте репозиторий и зарегистрируйте его:

```bash
ssh serv
mkdir -p "$HOME/g"
git clone git@github.com:jhoncool/yandex-skills.git "$HOME/g/yandex-skills"
cd "$HOME/g/yandex-skills"
./scripts/bootstrap-dev.sh
./scripts/validate-plugin.sh deep-code-review
codex plugin marketplace add "$PWD"
```

Затем установите `deep-code-review@yandex-skills`. Если на сервере уже установлен `deep-code-review@personal`, используйте показанную выше пару `codex plugin remove` и `codex plugin add` вместо одного `codex plugin add`.

После установки откройте новую задачу Codex: открытая задача использует снимок каталога скиллов, полученный при старте.

## Обновление плагина

Исходником считается копия в этом репозитории. Обычный цикл обновления выполняется на Mac:

```bash
cd /Users/shangin/g/yandex-skills

# Измените plugins/deep-code-review, затем создайте новую версию.
./scripts/bump-plugin-version.sh deep-code-review

git diff --check
git status --short
git add plugins/deep-code-review
git commit -m "Update deep-code-review"
git push

# Переустановите локальный снимок.
codex plugin add deep-code-review@yandex-skills
```

`bump-plugin-version.sh` сохраняет базовую semver-версию, заменяет суффикс на новый `+codex.<timestamp>` и запускает штатные валидаторы Codex. Не меняйте cachebuster отдельно на сервере: обе машины должны устанавливать одну закоммиченную версию.

После push обновите сервер:

```bash
ssh serv
cd "$HOME/g/yandex-skills"
git pull --ff-only
./scripts/validate-plugin.sh deep-code-review
codex plugin add deep-code-review@yandex-skills
```

Затем откройте новые задачи Codex на Mac и сервере. Проверить активную версию можно командой:

```bash
codex plugin list --json
```

## Добавление нового плагина

Штатный scaffold сразу создаёт каталог плагина и запись в marketplace:

```bash
cd /Users/shangin/g/yandex-skills
CODEX_ROOT="${CODEX_HOME:-$HOME/.codex}"

python3 "$CODEX_ROOT/skills/.system/plugin-creator/scripts/create_basic_plugin.py" \
  my-plugin \
  --path "$PWD/plugins" \
  --marketplace-path "$PWD/.agents/plugins/marketplace.json" \
  --with-skills \
  --with-marketplace \
  --category "Developer Tools"
```

После заполнения манифеста и скиллов:

```bash
./scripts/bump-plugin-version.sh my-plugin
git add plugins/my-plugin .agents/plugins/marketplace.json
git commit -m "Add my-plugin"
git push
codex plugin add my-plugin@yandex-skills
```

На сервере достаточно сделать `git pull --ff-only`, запустить `./scripts/validate-plugin.sh my-plugin` и выполнить `codex plugin add my-plugin@yandex-skills`.

Сохраняйте лицензии и сведения об исходной ревизии рядом с любыми включёнными сторонними материалами. Не храните в репозитории токены, ключи, cookies и локальные файлы аутентификации.

## Восстановление старой версии

История конкретного плагина доступна отдельно от остальных:

```bash
git log -- plugins/deep-code-review
```

Чтобы восстановить содержимое из выбранного коммита, верните каталог, создайте новый cachebuster, закоммитьте восстановление и пройдите обычное обновление:

```bash
git restore --source=<commit> -- plugins/deep-code-review
./scripts/bump-plugin-version.sh deep-code-review
```
