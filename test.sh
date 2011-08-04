#!/bin/sh

lua test_server.lua &
SERVER_PID=$!
lua test_client.lua
kill ${SERVER_PID}
