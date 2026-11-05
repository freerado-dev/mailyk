# Nastavenie prihlásenia cez Google a Microsoft (OAuth2)

Bez tohto kroku aplikácia funguje s heslom aplikácie (Gmail) alebo s vlastným IMAP serverom.
OAuth2 je potrebný hlavne pre **Outlook.com / Microsoft 365**, kde prihlásenie heslom väčšinou nefunguje.

Obe ID klientov sú verejné (nie sú tajné). Vložíš ich do `lib/oauth_config.dart` a znova zostavíš aplikáciu
(workflow na GitHube alebo `scripts/build_*.sh`). Schéma presmerovania sa do Androidu a macOS doplní samo.

## Google (Gmail)

1. Otvor <https://console.cloud.google.com> a vytvor nový projekt.
2. **APIs & Services → Library**: zapni **Gmail API** (nie je to povinné pre IMAP, ale pomáha pri schvaľovaní).
3. **OAuth consent screen**: typ **External**, vyplň názov aplikácie a svoj email.
   - Pridaj scope `https://mail.google.com/`.
   - Pridaj seba (a ďalších používateľov) medzi **Test users**.
4. **Credentials → Create credentials → OAuth client ID**:
   - Application type: **iOS**
   - Bundle ID: `sk.konverzo.konverzoMail` (Google ho pri tomto spôsobe prihlásenia nekontroluje)
5. Skopíruj **Client ID** (tvar `1234-abc.apps.googleusercontent.com`) do `googleClientId` v `lib/oauth_config.dart`.

**Dôležité obmedzenia Googlu:**
- Kým je aplikácia v režime **Testing**, Google po **7 dňoch** zneplatní obnovovací token a treba sa prihlásiť znova.
- Rozsah `https://mail.google.com/` je „restricted“. Na verejné vydanie pre cudzích ľudí Google vyžaduje overenie
  aplikácie a bezpečnostný audit. Na osobné použitie so Test users to nie je potrebné.
- Ak toto nechceš riešiť, použi pri Gmaile **heslo aplikácie** (myaccount.google.com/apppasswords).

## Microsoft (Outlook.com, Microsoft 365)

1. Otvor <https://portal.azure.com> → **Microsoft Entra ID → App registrations → New registration**.
2. Supported account types: **Accounts in any organizational directory and personal Microsoft accounts**.
3. Redirect URI: platforma **Mobile and desktop applications**, hodnota
   `<schéma>:/oauth2redirect`, kde `<schéma>` je:
   - `com.googleusercontent.apps.<prvá časť Google client ID>` ak máš nastavený Google, inak
   - `sk.konverzo.konverzo_mail`

   (Presnú hodnotu vypíše `scripts/prepare_platforms.sh` ako `OAuth redirect scheme`.)
4. **Authentication → Advanced settings**: **Allow public client flows = Yes**.
5. **API permissions → Add a permission → APIs my organization uses → Office 365 Exchange Online → Delegated**:
   `IMAP.AccessAsUser.All` a `SMTP.Send`. K nim pridaj Microsoft Graph: `openid`, `email`, `profile`, `offline_access`.
6. Skopíruj **Application (client) ID** do `microsoftClientId` v `lib/oauth_config.dart`.

U pracovných účtov môže správca tenantu vyžadovať súhlas, alebo mať SMTP AUTH vypnuté.

## Po úprave

Zostav aplikáciu znova. V okne „Pridať účet“ sa objaví tlačidlo **Prihlásiť sa cez Google / Microsoft**.
