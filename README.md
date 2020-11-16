# Telegram plug-in for Vera
This plug-in uses [Telegram API](https://core.telegram.org/bots/api) to send push notifications via a Telegram Bot.

It's comopatible with both Vera and openLuup.

# Installation
To install, simply upload the files in the release using Vera's feature (Go to *Apps*, then *Develop Apps*, then *Luup files* and select *Upload*) and then create a new device under Vera.

To create a new device, got to *Apps*, then *Develop Apps*, then *Create device*.

- Upnp Device Filename/Device File: *D_VeraTelegram1.xml*
- Upnp Implementation Filename/Implementation file: *I_VeraTelegram1.xml*
- Parent Device: none

# Configuration
After installation, ensure to change mandatory variables under your Device, then *Advanced*, then *Variables*.
Please adjust *BotToken*, and *DefaultChatID* to your settings.

## How to create a bot and get the keys
In order to run this plug-in, you'll need to create a Telegram Bot.
No worries, [it's all covered here](https://core.telegram.org/bots). Go to point [#3]([https://core.telegram.org/bots#3-how-do-i-create-a-bot) for instructions.

# Use in code

You can send a text message:
```
luup.call_action("urn:bochicchio-com:serviceId:VeraTelegram1", 
  "Send",
  {
     Text="Hello from Vera", 
     ChatID = whatever
  }, 515)
```

Or an image:
```
luup.call_action("urn:bochicchio-com:serviceId:VeraTelegram1", 
  "Send",
  {
     Text="Hello from Vera",
     ImageUrl="https://media.giphy.com/media/3o84sIqsVAJNfWyjy8/giphy.gif"
  }, 515)
```


Or a a gif/video:

```
luup.call_action("urn:bochicchio-com:serviceId:VeraTelegram1", 
  "Send",
  {
     Text="Hello from Vera", 
     VideoUrl="https://media.giphy.com/media/3o84sIqsVAJNfWyjy8/giphy.gif"
  }, 515)
```

Or a silent notification:
You can send a message:
```
luup.call_action("urn:bochicchio-com:serviceId:VeraTelegram1", 
  "Send",
  {
     Text="Hello from Vera (Silent)",
     DisableNotification = true
  }, 515)
```

Where *515* is your device ID, ChatID is the chat id (if omitted DefaultChatID variable will be use).

## Formatting messages

You can format your message using HTML or Markdown (default).

Send in HTML (see below for supported tags):
```
luup.call_action("urn:bochicchio-com:serviceId:VeraTelegram1", 
  "Send",
  {
     Text="This is <b>bold</b>\nHTML message!",
     Format = "HTML",
     DisableNotification = false
  }, 515)
```

Or in Markdown (see below for supported format):

```
luup.call_action("urn:bochicchio-com:serviceId:VeraTelegram1", 
  "Send",
  {
     Text="This is *bold*\nMarkdown message!",
     Format = "MarkdownV2",
     DisableNotification = false
  }, 515)
```

[See options for tags and formats.](https://core.telegram.org/bots/api#formatting-options).

# OpenLuup/AltUI
The device is working and supported under OpenLuup and AltUI.
In this case, if you're using an old version of AltUI/OpenLoop, just be sure the get the base service file from Vera (automatically done if you have the Vera Bridge installed).

# Support
If you need more help, please post on Vera's forum and tag me (@therealdb).
https://community.getvera.com/t/telegram-plug-in-to-send-text-images-and-video-notifications/215219