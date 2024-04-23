#!/bin/sh

# Set the has_failed variable to false. This will change if any of the subsequent database backups/uploads fail.
has_failed=false

echo "Start" > /tmp/kubernetes-mysql-sync.log

if [ "$GOOGLE_CHAT_ENABLED" = "true" ]; then
    /google-chat-alert.sh "Starting sync database on host $SOURCE_DATABASE_HOST."
fi

# Set the BACKUP_CREATE_DATABASE_STATEMENT variable
if [ "$BACKUP_CREATE_DATABASE_STATEMENT" = "true" ]; then
    BACKUP_CREATE_DATABASE_STATEMENT="--databases"
else
    BACKUP_CREATE_DATABASE_STATEMENT=""
fi


if [ "$TARGET_ALL_DATABASES" = "true" ]; then
    # Ignore any databases specified by SOURCE_DATABASE_NAMES
    if [ ! -z "$SOURCE_DATABASE_NAMES" ]
    then
        echo "Both TARGET_ALL_DATABASES is set to 'true' and databases are manually specified by 'SOURCE_DATABASE_NAMES'. Ignoring 'SOURCE_DATABASE_NAMES'..."
        SOURCE_DATABASE_NAMES=""
    fi
    # Build Database List
    ALL_DATABASES_EXCLUSION_LIST="'mysql','sys','tmp','information_schema','performance_schema'"
    ALL_DATABASES_SQLSTMT="SELECT schema_name FROM information_schema.schemata WHERE schema_name NOT IN (${ALL_DATABASES_EXCLUSION_LIST})"
    if ! ALL_DATABASES_DATABASE_LIST=`mysql -u $SOURCE_DATABASE_USER -h $SOURCE_DATABASE_HOST -p$SOURCE_DATABASE_PASSWORD -P $SOURCE_DATABASE_PORT -ANe"${ALL_DATABASES_SQLSTMT}"`
    then
        echo -e "Building list of all databases failed at $(date +'%d-%m-%Y %H:%M:%S')." | tee -a /tmp/kubernetes-mysql-sync.log
        has_failed=true
    fi
    if [ "$has_failed" = false ]; then
        for DB in ${ALL_DATABASES_DATABASE_LIST}
        do
            SOURCE_DATABASE_NAMES="${SOURCE_DATABASE_NAMES}${DB},"
        done
        #Remove trailing comma
        SOURCE_DATABASE_NAMES=${SOURCE_DATABASE_NAMES%?}
        echo -e "Successfully built list of all databases (${SOURCE_DATABASE_NAMES}) at $(date +'%d-%m-%Y %H:%M:%S')."
    fi
fi

# Loop through all the defined databases, seperating by a ,
if [ "$has_failed" = false ]; then
    for CURRENT_DATABASE in ${SOURCE_DATABASE_NAMES//,/ }; do

        # TODO
        #DUMP=$CURRENT_DATABASE$(date +$BACKUP_TIMESTAMP).sql
        DUMP=$CURRENT_DATABASE.sql
        # Perform the database dump. Put the output to a variable. If successful upload the target mysql, if unsuccessful print an entry to the console and the log, and set has_failed to true.
        if sqloutputDump=$(mysqldump -u $SOURCE_DATABASE_USER -h $SOURCE_DATABASE_HOST -p$SOURCE_DATABASE_PASSWORD -P $SOURCE_DATABASE_PORT $BACKUP_ADDITIONAL_PARAMS $BACKUP_CREATE_DATABASE_STATEMENT $CURRENT_DATABASE 2>&1 >/tmp/$DUMP); then

            echo -e "Database dump successfully completed for $CURRENT_DATABASE at $(date +'%d-%m-%Y %H:%M:%S')."

            # Perform the database sync. Put the output to a variable. if unsuccessful print an entry to the console and the log, and set has_failed to true.
            if sqloutputSync=$(mysqldump -u $TARGET_DATABASE_USER -h $TARGET_DATABASE_HOST -p$TARGET_DATABASE_PASSWORD -P $TARGET_DATABASE_PORT 2>&1 </tmp/$DUMP); then

                echo -e "Database sync successfully completed for $CURRENT_DATABASE at $(date +'%d-%m-%Y %H:%M:%S')."

            else
                echo -e "Database SYNC FAILED for $CURRENT_DATABASE at $(date +'%d-%m-%Y %H:%M:%S'). Error: $sqloutputSync" | tee -a /tmp/kubernetes-mysql-sync.log
                has_failed=true
            fi

        else
            echo -e "Database DUMP FAILED for $CURRENT_DATABASE at $(date +'%d-%m-%Y %H:%M:%S'). Error: $sqloutputDump" | tee -a /tmp/kubernetes-mysql-sync.log
            has_failed=true
        fi

    done
fi

# Check if any of the sync have failed. If so, exit with a status of 1. Otherwise exit cleanly with a status of 0.
if [ "$has_failed" = true ]; then

    # Convert GOOGLE_CHAT_ENABLED to lowercase before executing if statement
    GOOGLE_CHAT_ENABLED=$(echo "$GOOGLE_CHAT_ENABLED" | awk '{print tolower($0)}')

    if [ "$GOOGLE_CHAT_ENABLED" = "true" ]; then
        # Put the contents of the database syncs logs into a variable
        logcontents=$(cat /tmp/kubernetes-mysql-sync.log)

        # Send Google Chat alert
        /google-chat-alert.sh "One or more syncs on database host $SOURCE_DATABASE_HOST failed. The error details are included below:" "$logcontents"
    fi

    echo -e "kubernetes-mysql-sync encountered 1 or more errors. Exiting with status code 1."
    exit 1

else

    if [ "$GOOGLE_CHAT_ENABLED" = "true" ]; then
        /google-chat-alert.sh "All database synced successfully completed on database host $SOURCE_DATABASE_HOST."
    fi

    exit 0

fi
