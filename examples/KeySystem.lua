local UI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Proxo123/Kinoue-Lib/main/dist/Kinoue.lua"))()

return UI:CreateKeySystem({
    Name = "My script",
    Application = "my-script",
    Endpoint = "https://keys.example.com",
    CachePath = "MyScript/auth.json",
    Remember = true,
})
