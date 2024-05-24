printf "#################################################################\n"
printf "check phaidra mariadb integrity...\n"
printf "#################################################################\n"
mysqlcheck \
    -h mariadb-phaidra \
    -u root \
    -p${MARIADB_ROOT_PASSWORD} \
    ${PHAIDRADB}
printf "#################################################################\n"
printf "dump phaidra mariadb...\n"
printf "#################################################################\n"
mariadb-dump \
    -h mariadb-phaidra \
    -u root \
    -p${MARIADB_ROOT_PASSWORD} \
    -x ${PHAIDRADB} | \
    gzip > /mnt/database-dumps/$(date +%F-%H-%M-%S)-${PHAIDRADB}.sql.gz
