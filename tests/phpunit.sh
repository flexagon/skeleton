#!/bin/sh
set -eu

PHPUNIT="../vendor/bin/phpunit"
CONFIG="../phpunit.xml"

TARGET=${1-}
FILTER=${2-}

ENV1=""
ENV2=""
ENV3=""
ENV4=""
ENV5=""

OPT1=""
OPT2=""
OPT3=""
OPT4=""
OPT5=""

ENV_COUNT=0
OPT_COUNT=0

for ARG in "${3-}" "${4-}" "${5-}" "${6-}" "${7-}"; do
  [ -z "$ARG" ] && continue

  case "$ARG" in
    *=*|*:*)
      ENV_COUNT=$((ENV_COUNT + 1))

      # ':' → '=' 변환
      case "$ARG" in
        *=*) ENV_VAL="$ARG" ;;
        *:*) ENV_VAL=$(printf "%s" "$ARG" | sed 's/:/=/') ;;
      esac

      case "$ENV_COUNT" in
        1) ENV1="$ENV_VAL" ;;
        2) ENV2="$ENV_VAL" ;;
        3) ENV3="$ENV_VAL" ;;
        4) ENV4="$ENV_VAL" ;;
        5) ENV5="$ENV_VAL" ;;
        *) echo "Too many ENV arguments. Max 5 allowed." >&2; exit 1 ;;
      esac
      ;;
    --*)
      OPT_COUNT=$((OPT_COUNT + 1))
      case "$OPT_COUNT" in
        1) OPT1="$ARG" ;;
        2) OPT2="$ARG" ;;
        3) OPT3="$ARG" ;;
        4) OPT4="$ARG" ;;
        5) OPT5="$ARG" ;;
        *) echo "Too many PHPUnit options. Max 5 allowed." >&2; exit 1 ;;
      esac
      ;;
    *)
      echo "Invalid argument: $ARG" >&2
      echo "Use KEY=VALUE, KEY:VALUE or --phpunit-option" >&2
      exit 1
      ;;
  esac
done

if [ -n "$ENV1" ]; then
  ENV_CMD="env"
else
  ENV_CMD=""
fi

if [ -n "$FILTER" ]; then
  exec ${ENV_CMD} \
    ${ENV1:+"$ENV1"} ${ENV2:+"$ENV2"} ${ENV3:+"$ENV3"} ${ENV4:+"$ENV4"} ${ENV5:+"$ENV5"} \
    php "$PHPUNIT" \
    --configuration "$CONFIG" \
    --filter "$FILTER" \
    "$TARGET" \
    ${OPT1:+"$OPT1"} ${OPT2:+"$OPT2"} ${OPT3:+"$OPT3"} ${OPT4:+"$OPT4"} ${OPT5:+"$OPT5"}
else
  exec ${ENV_CMD} \
    ${ENV1:+"$ENV1"} ${ENV2:+"$ENV2"} ${ENV3:+"$ENV3"} ${ENV4:+"$ENV4"} ${ENV5:+"$ENV5"} \
    php "$PHPUNIT" \
    --configuration "$CONFIG" \
    "$TARGET" \
    ${OPT1:+"$OPT1"} ${OPT2:+"$OPT2"} ${OPT3:+"$OPT3"} ${OPT4:+"$OPT4"} ${OPT5:+"$OPT5"}
fi