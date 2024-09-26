table.insert(ao.authorities, 'fcoN_xJeisVsPXA-trzVAuIiqO3ydLQxM-L4XbrQKzY')
Handlers.prepend("isTrusted",
        function (msg)
            return msg.From ~= msg.Owner and not ao.isTrusted(msg)
        end,
        function (msg)
            Send({Target = msg.From, Data = "Message is not trusted."})
            print("Message is not trusted. From: " .. msg.From .. " - Owner: " .. msg.Owner)
        end
)