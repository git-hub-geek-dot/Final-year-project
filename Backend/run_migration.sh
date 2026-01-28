#!/bin/bash

# Database connection details (update these with your actual values)
DB_HOST="localhost"
DB_NAME="volunteerx_db"
DB_USER="postgres"
DB_PASSWORD="postgres"  # Update if different
DB_PORT="5432"

# Run the migration
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME -p $DB_PORT -f add_profile_picture_column.sql

echo "Migration completed!"
