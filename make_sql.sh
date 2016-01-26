#!/bin/bash

VERSION="0.0.1"

FILES="src/assert.sql
src/assertions/*.sql"


echo "
\echo Use \"CREATE EXTENSION assert\" to load this file. \quit

set statement_timeout     = 0;
set client_encoding       = 'UTF8';
set client_min_messages   = warning;
set escape_string_warning = off;
set standard_conforming_strings = on;

" > "assert--$VERSION.sql"

for file in $FILES
do
	echo "
    /* $file */
	" >> "assert--$VERSION.sql"

	cat $file >> "assert--$VERSION.sql"
done
