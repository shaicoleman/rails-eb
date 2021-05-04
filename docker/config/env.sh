#!/bin/bash
export RAILS_ENV=staging
export NODE_ENV=production
export DATABASE_URL="postgresql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}"
export PATH="$HOME/.gem/ruby/2.6.0/bin:$HOME/ruby/bin:$HOME/node/bin:$HOME/file/bin:$HOME/wkhtmltopdf/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export MALLOC_ARENA_MAX=2
