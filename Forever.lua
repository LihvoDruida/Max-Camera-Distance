-- WoW: Forever (codename Camelot) load-time flavor marker.
--
-- Forever currently reports the mainline project ID because its UI/runtime is
-- based on the modern client. That means WOW_PROJECT_ID alone cannot separate
-- it from Retail. This file is intentionally referenced ONLY by the Camelot
-- TOC so Compat.lua gets an unambiguous flavor signal before it classifies the
-- client.
local _, ns = ...

ns.ClientFlavor = ns.ClientFlavor or {}
ns.ClientFlavor.FOREVER = true
ns.ClientFlavor.SOURCE = "Camelot TOC"
