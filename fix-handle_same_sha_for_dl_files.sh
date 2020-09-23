#!/bin/bash
mkdir -p ./library
cp /usr/lib/python3.8/site-packages/ansible/modules/net_tools/basics/get_url.py ./library/
patch -u ./library/get_url.py < ./fix-handle_same_sha_for_dl_files.patch
