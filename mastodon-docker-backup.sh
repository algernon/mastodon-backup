#! /bin/sh
## Backup important data from a Mastodon instance
## Copyright (C) 2017 Gergely Nagy
##
## Released under the WTFPL, see LICENSE.

BACKUPDIR="${BACKUPDIR:-$(pwd)/backup}"
MASTODON_DIR="${MASTODON_DIR:-./public}"
DESTDIR="${BACKUPDIR}"
install -d "${DESTDIR}"

list_local_media() {
    LMTMP=$(tempfile)
    docker exec -t mastodon_db_1 psql -U postgres -q -P pager=off -c \
           'select ma.id, ma.file_file_name from media_attachments ma, accounts a where a.id = ma.account_id and a.domain is NULL;' \
        | head -n -2 | tail -n +3 > ${LMTMP}

    IFS="
"
    for line in $(cat ${LMTMP}); do
        id=$(echo $line | cut -d "|" -f 1 | tr -d " ")
        fn=$(echo $line | cut -d "|" -f 2 | tr -d " " | sed -e "s,\r,,")
        url="system/media_attachments/files/$(printf "%09d" $id | sed -e 's,\(...\),\1/,g')original/$fn"
        echo $url
    done
    rm -f "${LMTMP}"
}

echo "* Copying configuratior..."
cp ${MASTODON_DIR}/../.env.production ${MASTODON_DIR}/../docker-compose.yml ${DESTDIR}/

echo "* Archiving local media..."
cd "${MASTODON_DIR}"
tar -cv --ignore-failed-read -f "${DESTDIR}/local-media.tar" $(list_local_media) 2>/dev/null

echo "* Dumping the database..."
docker exec -t mastodon_db_1 pg_dumpall -c -U postgres | xz >"${DESTDIR}/db.sql.xz"
