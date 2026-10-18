#!/bin/sh
# Checks FLEXAGON_PUBLIC before Apache starts, which on its own would serve 404s
# from a missing directory, and sizes the prefork pool to the container's
# memory. Writes nothing -- the results go to Apache as environment variables
# -- so a read-only root file system and a non-root user both work.
set -eu

case "$FLEXAGON_PUBLIC" in
    public|public_*) ;;
    *)
        echo "flexagon: FLEXAGON_PUBLIC=$FLEXAGON_PUBLIC -- must be public or public_<name>" >&2
        exit 1 ;;
esac
case "$FLEXAGON_PUBLIC" in
    */*|*..*)
        echo "flexagon: FLEXAGON_PUBLIC=$FLEXAGON_PUBLIC -- a directory name, not a path" >&2
        exit 1 ;;
esac
if [ ! -f "/app/$FLEXAGON_PUBLIC/__flexagon.php" ]; then
    echo "flexagon: /app/$FLEXAGON_PUBLIC/__flexagon.php not found" >&2
    exit 1
fi

# -- prefork pool ------------------------------------------------------------
# Every request holds one PHP process for its whole length. Debian's 150 of
# them at ~50MB each is 7GB, so a 512MB container is killed under load instead
# of queueing. Size the pool to what the memory limit can hold.

is_number() {
    case "$1" in ''|*[!0-9]*) return 1 ;; esac
}

# The container's memory limit in MB: the cgroup limit, or the machine when
# there is none (cgroup v2 says "max", v1 a number larger than the machine).
memory_mb() {
    total=$(awk '/^MemTotal:/ { print int($2 / 1024) }' /proc/meminfo)
    limit=""
    if [ -r /sys/fs/cgroup/memory.max ]; then
        limit=$(cat /sys/fs/cgroup/memory.max)
    elif [ -r /sys/fs/cgroup/memory/memory.limit_in_bytes ]; then
        limit=$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes)
    fi
    if is_number "$limit" && [ $((limit / 1048576)) -lt "$total" ]; then
        echo $((limit / 1048576))
    else
        echo "$total"
    fi
}

for name in APACHE_WORKER_MEMORY_MB APACHE_RESERVED_MEMORY_MB APACHE_MAX_CONNECTIONS_PER_CHILD; do
    eval "value=\${$name}"
    if ! is_number "$value"; then
        echo "flexagon: $name=$value -- must be a whole number" >&2
        exit 1
    fi
done
if [ "$APACHE_WORKER_MEMORY_MB" -lt 1 ]; then
    echo "flexagon: APACHE_WORKER_MEMORY_MB must be at least 1" >&2
    exit 1
fi

if [ "$APACHE_MAX_REQUEST_WORKERS" = auto ]; then
    memory=$(memory_mb)
    workers=$(( (memory - APACHE_RESERVED_MEMORY_MB) / APACHE_WORKER_MEMORY_MB ))
    [ "$workers" -ge 2 ] || workers=2
    [ "$workers" -le 256 ] || workers=256
    sizing="auto: ${memory}MB - ${APACHE_RESERVED_MEMORY_MB}MB reserved, ${APACHE_WORKER_MEMORY_MB}MB each"
elif is_number "$APACHE_MAX_REQUEST_WORKERS" && [ "$APACHE_MAX_REQUEST_WORKERS" -ge 1 ]; then
    workers=$APACHE_MAX_REQUEST_WORKERS
    sizing="set by APACHE_MAX_REQUEST_WORKERS"
else
    echo "flexagon: APACHE_MAX_REQUEST_WORKERS=$APACHE_MAX_REQUEST_WORKERS -- auto or a positive number" >&2
    exit 1
fi

smaller() { [ "$1" -lt "$2" ] && echo "$1" || echo "$2"; }

export APACHE_PREFORK_WORKERS="$workers"
export APACHE_PREFORK_START=$(smaller 5 "$workers")
export APACHE_PREFORK_MIN_SPARE=$(smaller 5 "$workers")
export APACHE_PREFORK_MAX_SPARE=$(smaller 10 "$workers")

echo "flexagon: serving /app/$FLEXAGON_PUBLIC on port $PORT" >&2
echo "flexagon: $workers workers ($sizing)" >&2
exec docker-php-entrypoint "$@"
