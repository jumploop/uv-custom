        # --- Customization: Verify checksums for runtime-selected versions ---
        if [ "$APP_VERSION" != "__GENERATED_VERSION__" ]; then
            local _checksum_file
            _checksum_file="$_dir/input$_zip_ext.sha256"
            if ! downloader "$_url.sha256" "$_checksum_file"; then
                err "failed to download checksum $_url.sha256"
            fi
            _checksum_style="sha256"
            _checksum_value="$(awk 'NR == 1 { print $1 }' "$_checksum_file")"
            if [ -z "$_checksum_value" ]; then
                err "empty checksum file: $_url.sha256"
            fi
        fi
        # --- Customization End ---
