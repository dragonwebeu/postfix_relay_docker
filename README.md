# Posfix relay mail server

#### Features
- TSL
- DKIM
- Postfix log entry summarizer
- Limit when emails are sent out (optional)
- Max email size 50MB
- SPF [How to add SPF](#how-to-add-spf)
- DMARC [How to add DMARC](#how-to-add-dmarc)

## Quick setup

####  1. Edit postfix main conf
[build/postfix/main.cf](build/postfix/main.cf)

```
myhostname = mail.example.eu
smtp_helo_name = mail.example.eu
mydomain = example.eu
mynetworks = 192.0.2.0/24 192.0.0.0/24 192.0.0.60
```
#### 2. Edit DKIM conf file
[build/dkim/DKIM_opendkim.conf](build/dkim/DKIM_opendkim.conf)
`InternalHosts		192.168.0.0/16, 10.0.0.0/8, 172.16.0.0/12`

#### 3. Add SPF  record to your domain
#### 4. Spin up Docker with docker compose
```
1. cd to cloned path
2. docker compose up -d
```

#### 5. Go inside container test send email

```
1. cd to cloned path
2. docker compose exec ee bash
3. echo "Docker relay test" | mail -a "From: no-replay@example.eu" -s "Postfix `hostname` report of `date`" my_email@example.eu
```

---

## In-depth documentation on how to set Docker Postfix relay server

#### 1. Generate SSL certificate or add it to `<country code>/ssl` folder or use default one ([How to generate SSL certificate?](#how-to-generate-ssl-certificate))

If you don't one want to use default TSL, edit files:
[build/Dockerfile](build/Dockerfile)
[build/postfix/main.cf](build/postfix/main.cf)
  
If you want that TSL will be country specify you can change `docker-compose.yml` file, add volume out to just SSL


#### 2. If you send emails to older inboxes, you should add a mail server pointer (PTR record). It needs to be resolved both ways.

`mail.example.com A xxx.xxx.xxx` under your domain DNS and server machine should point to
`0.0.0.195.in-addr.arpa domain name pointer mail.example.com.`

#### 3. Add IP to SPF (([How to add SPF](#spf)))/ Add SPF to your domain DNS record
#### 4. Setup IP or IP range which allowed to send emails trough postfix relay
Edit: [build/postfix/main.cf](build/postfix/main.cf)

Example:
`mynetworks = 192.0.2.0/24 192.0.0.0/24 192.0.0.60`

Edit: [build/dkim/DKIM_opendkim.conf](build/dkim/DKIM_opendkim.conf)
`InternalHosts		192.168.0.0/16, 10.0.0.0/8, 172.16.0.0/12`


#### 5. Optional - Limit when emails are sent out

If your country does not allow sending out emails at night you should edit crontabs.

Edit: [build/crontab/default_crontab](build/crontab/default_crontab)


#### 6. Setup [DKIM](#how-to-add-dkim) 

#### 6. Setup [DMARC](#how-to-add-dmarc) 

#### 7. edit .env file to setup locales and mailname
[build/.env](build/.env)

----

### How to generate SSL certificate?
Currenct certificate is generated for 5 years
```
cd /srv/postfix/ssl or cd /srv/postfix/<country code>/ssl
sudo openssl genrsa -des3 -out mail.server.key 2048
sudo chmod 600 mail.server.key
sudo openssl req -new -key mail.server.key -out mail.server.csr
sudo openssl x509 -req -days 1825 -in mail.server.csr -signkey mail.server.key -out mail.server.crt
sudo openssl rsa -in mail.server.key -out mail.server.key.nopass
sudo mv mail.server.key.nopass mail.server.key
sudo openssl req -new -x509 -extensions v3_ca -keyout cakey.pem -out cacert.pem -days 3650
sudo chmod 600 mail.server.key
sudo chmod 600 cakey.pem
```

## How to add SPF

It is important to add the following line: `ip4:<your ip here>` for the mail server's outgoing IP, otherwise the SPF will not pass validation.

```bash
1. curl ifconfig.me
2. example.com TEXT v=spf1 a mx include:mail.spf.elkdata.ee ip4:127.0.0.1 ~all
```

For more details here is a Google article https://support.google.com/a/answer/10683907?hl=en

PS! If you are using Outlook I recommend using `~all` because Microsoft sometimes send emails from servers which are not yet in the SPF list otherwise `-all` is recommended.

## How to add DKIM
**Create a key table**
```
nano /etc/opendkim/KeyTable
```
A key table contains each selector/domain pair and the path to their private key.
```
mail._domainkey.example.com example.com:mail:/etc/opendkim/keys/example.com/mail.private
```
**Create a signing table:**
```
nano /etc/opendkim/SigningTable
```
This file is used for declaring the domains/email addresses and their selectors.
```
*@example.com mail._domainkey.example.com
```

### Generate the public and private keys

```
mkdir /etc/opendkim/keys/example.com 
opendkim-genkey -d example.com -D /etc/opendkim/keys/example.com -s mail
cd /etc/opendkim/keys/example.com
chown opendkim:opendkim mail.private
cat mail.txt 
```

### Add DKIM key to domain DNS zone
**Name:**
`mail._domainkey.example.com`

**Value:**
`v=DKIM1; h=sha256; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAtEf2NpSMq3tto/4biQkC09Inv8K9NLBVw2Coa5WQ4kIWfgZYXf4zH97x4DsnezuOPsifonfl0B8Sm0DSgP8M8sXW7DI52TlnIuvsTVoOWb//PXvMRc9fNKv71m+nFGirN9j+MvQlLUlnAhgpk4PMWzLmP1XJCMGqL27rytlC6MYjPH9+vvU99b5sIhrax5GA+SyQyilab7jog6Cs8Biq38rtpziAsBMqJ/ahU8GP+DbJ5hejPf4OuR6e1tARx/jsdRCul/YVsc5ggs1u7XIp+c8NRjv3oo5ZmnfnUHzCxwSYh1nxn7tDk302RHjJnFzx5xG+yJGi7vNY07bGAh2YswIDAQAB`

PS! Clean up key text, remove spaces and quotes.

### Test Key added to domain
`opendkim-testkey -d example.com -s mail -vvv`


## How to add DMARC

Add to your DNS record

PS! First monitor how emails are sent out, then make fixed rules

Read more https://support.google.com/a/answer/2466580?hl=en#dmarc-prep-record

```
v=DMARC1; p=none; adkim=r; aspf=r; rua=mailto:dmarc.report@example.eu; ruf=mailto:dmarc.report@example.ee; fo=1
```

---

# Postfix service commands

**Go inside container**
`cd /src/postfix && docker-compose exec ee bash`

**List all emails - you can list all mail of queue, using one of the following commands:**

`postqueue -p` or `mailq`

**Flush all emails - To delete or flush all emails from Postfix mail queue using the following command:**

`postsuper -d ALL`

**Flush deferred mails only - use the following command to delete deferred emails from the queue.**

`postsuper -d ALL deferred`