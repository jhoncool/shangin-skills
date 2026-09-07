# Разработка и сопровождение shangin-skills

Этот документ предназначен для агента или разработчика, который меняет плагины, выпускает новые версии, синхронизирует установки или добавляет плагины в marketplace.

## Источник истины

Исходники хранятся в Git-репозитории `git@github.com:jhoncool/shangin-skills.git`. Изменения сначала вносятся в checkout репозитория, проходят проверку и получают новую версию, затем коммитятся и устанавливаются на нужных машинах.

Не редактируйте установленный кэш Codex как источник изменений. Не создавайте разные cachebuster-версии одного выпуска на Mac и `serv`.

## Структура

```text
.agents/plugins/marketplace.json  # общий каталог Codex-плагинов
plugins/
  deep-code-review/               # самодостаточный плагин
    scripts/doctor.sh             # проверка runtime-зависимостей
requirements-dev.txt              # зависимости валидаторов
scripts/
  bootstrap-dev.sh                # создаёт локальное .venv
  bump-plugin-version.sh          # обновляет cachebuster и валидирует
  validate-marketplace.py         # проверяет целостность каталога
  validate-plugin.sh              # проверяет plugin.json и все SKILL.md
```

Каждый плагин хранится в `plugins/<plugin-name>` и содержит `.codex-plugin/plugin.json`. Имя каталога, `plugin.json.name` и запись в `.agents/plugins/marketplace.json` должны совпадать.

## Политика зависимостей Deep Code Review

- `git` — обязательная внешняя программа.
- `gh` — рекомендуемая внешняя программа; при её отсутствии поддерживается ограниченный git-only режим.
- Matt Pocock `code-review` хранится внутри плагина как reference-зависимость вместе с лицензией и сведениями об исходной ревизии. Пользователь не устанавливает его отдельно.
- `deep-code-review` и `github-pr-worktree-review` поставляются одним плагином.
- `datalens-team-skills:startrek` остаётся опциональной внешней интеграцией.

Плагин не должен молча устанавливать системные программы или внешние плагины. Обязательные зависимости проверяются до работы и приводят к понятной ошибке; отсутствие опциональной зависимости отражается как ограничение результата.

`plugins/deep-code-review/scripts/doctor.sh` — единая исполняемая проверка для обоих скиллов. При изменении требований обновляйте вместе сам скрипт, preflight-разделы обоих `SKILL.md`, install-facing метаданные в `plugin.json` и пользовательскую таблицу в `README.md`.

## Подготовка checkout

```bash
cd /Users/shangin/g/shangin-skills
./scripts/bootstrap-dev.sh
./scripts/validate-plugin.sh deep-code-review
```

`.venv` используется только для штатных Python-валидаторов Codex и игнорируется Git.

## Изменение и выпуск плагина

1. Измените файлы внутри `plugins/<plugin-name>`.
2. Обновите cachebuster и запустите все проверки:

   ```bash
   ./scripts/bump-plugin-version.sh deep-code-review
   ```

3. Проверьте итоговый diff:

   ```bash
   git diff --check
   git status --short
   git diff -- plugins/deep-code-review .agents/plugins/marketplace.json
   ```

4. Создайте коммит и отправьте его:

   ```bash
   git add plugins/deep-code-review .agents/plugins/marketplace.json
   git commit -m "Update deep-code-review"
   git push
   ```

Не меняйте cachebuster повторно на сервере. Сервер должен получить тот же коммит и ту же версию.

## Обновление установленного плагина

Если marketplace добавлен из Git, после push выполните локально:

```bash
codex plugin marketplace upgrade shangin-skills
codex plugin add deep-code-review@shangin-skills
```

На `serv`:

```bash
ssh serv
codex plugin marketplace upgrade shangin-skills
codex plugin add deep-code-review@shangin-skills
```

Если на машине используется checkout как локальный marketplace, обновите checkout командой `git pull --ff-only` и затем повторите `codex plugin add`.

После переустановки откройте новую задачу Codex. Проверить активную версию:

```bash
codex plugin list --json
```

## Добавление нового плагина

Штатный scaffold создаёт каталог плагина и запись в общем marketplace:

```bash
cd /Users/shangin/g/shangin-skills
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
```

Затем обновите marketplace и установите `my-plugin@shangin-skills` на каждой нужной машине.

## Проверки

`./scripts/validate-plugin.sh <plugin-name>` выполняет:

1. Проверку целостности `.agents/plugins/marketplace.json`.
2. Штатную проверку `.codex-plugin/plugin.json`.
3. Штатную проверку каждого обнаруживаемого `SKILL.md`.

Для shell-скриптов дополнительно запускайте `bash -n`. Для поведения скриптов плагина сохраняйте целевые интеграционные сценарии, которые проверяют реальные ветки ошибок и неизменяемость выбранного scope.

Для Deep Code Review также запустите doctor в обоих режимах:

```bash
./plugins/deep-code-review/scripts/doctor.sh --workflow deep-code-review
./plugins/deep-code-review/scripts/doctor.sh --workflow github-pr-worktree-review
```

## Восстановление старой версии

```bash
git log -- plugins/deep-code-review
git restore --source=<commit> -- plugins/deep-code-review
./scripts/bump-plugin-version.sh deep-code-review
```

Восстановление оформляется новым коммитом и новым cachebuster, после чего проходит обычный процесс установки.

## Контрольный список перед push

- Рабочий diff соответствует запрошенному изменению.
- Marketplace, каталог плагина и `plugin.json.name` согласованы.
- Версия содержит один актуальный `+codex.<cachebuster>`.
- Лицензии и сведения об исходной ревизии сторонних материалов сохранены.
- В репозитории нет токенов, ключей, cookies и файлов аутентификации.
- Валидаторы и релевантные интеграционные проверки прошли.
- README содержит только пользовательскую установку и примеры использования; инструкции сопровождения находятся в этом документе.
