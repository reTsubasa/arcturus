return {
    mode = "development", -- development | production
    env = {
        development = {
            port = 81,
            webui = true,
            webui_port = 8081,
            worker_num = 1,
            path = {
                base = "/etc/arcturus"
            },
            pcre = "imjo"
        }
    }
}
