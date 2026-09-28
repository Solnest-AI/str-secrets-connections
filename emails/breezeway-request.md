**To:** support@breezeway.io
**Subject:** Client API credentials for my Breezeway account

Hi Breezeway team,

I'm a Breezeway account holder using it for my own short-term rental properties. I'm not a software vendor or partner, and I'm not building an integration for anyone else.

I'd like Client API credentials so an AI assistant (Claude) on my own computer can read data from my own account. Single account, low volume, read-only. Nothing gets created or changed in Breezeway.

The data I need to read:
- Properties: list and details
- Reservations: so tasks line up with stays
- Tasks: cleaning, inspection and maintenance tasks, with status and costs

I don't need guest messaging through the API, people or staff records, or write access.

Could you please issue a client_id and client_secret for my account (the email I'm writing from)? I've read developer.breezeway.io/docs/obtaining-credentials, so I know what to do once I have them.

Thanks,
<name>
<company, number of properties>

---
**If Breezeway replies asking which data you need** (they have asked attendees "which data do you need access to? properties, reservations, tasks, people, etc."), or you already sent them a vaguer answer, reply on the same thread with:

Hi,

Thanks for getting back to me. To clarify: I'm a Breezeway account holder, not a software vendor. An AI assistant (Claude) on my own computer reads my own account so I can review my properties' operating costs alongside my pricing and occupancy. My own portfolio only, low volume, not a product for anyone else.

I don't need guest communications through the API, and I'm not building a sync with another system.

Read-only access is all I need, for:
- Properties: list and details
- Reservations: so tasks line up with stays
- Tasks: cleaning, inspection and maintenance tasks, with status and costs

I don't need people or staff records, and I don't need to create or change anything.

Thanks,
<name>
<company, number of properties>

---
**If Breezeway quotes a monthly API fee:** don't agree to it. Reply that you only need read access to your own account and ask them to confirm there is no charge. Breezeway is optional for the summit, so a pending request never blocks you.

When they reply with the credentials: do not paste them into the chat. Tell Claude "Breezeway is enabled" and re-run Check my connections. Claude will open the .env file for you to drop the client_id and client_secret in, then make one real call to prove it works. You also filled Breezeway's Client API Request Form on day one (https://share.hsforms.com/1u3FL41u0TBqTZYMmW_VmqA1l00c), so if you get no reply after a few days, reply to this same email thread with the date you submitted the form and ask them to confirm they have the request.
