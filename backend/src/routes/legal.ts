const STYLE = `
  *{box-sizing:border-box}
  body{margin:0;background:#FFF8F0;font-family:'Helvetica Neue',Arial,sans-serif;padding:40px 24px}
  .wrap{max-width:720px;margin:0 auto;background:#fff;border-radius:24px;border:2px solid #EFE4D2;padding:48px 40px;box-shadow:0 4px 0 #EFE4D2}
  h1{font-size:28px;font-weight:800;color:#1F1B16;margin:0 0 4px}
  .sub{color:#A39A8C;font-size:13px;margin:0 0 32px;border-bottom:1px solid #EFE4D2;padding-bottom:20px}
  h2{font-size:15px;font-weight:700;color:#1F1B16;margin:32px 0 8px;text-transform:uppercase;letter-spacing:.4px}
  p,li{font-size:14px;color:#4A4035;line-height:1.75;margin:0 0 10px}
  ul,ol{margin:0 0 10px;padding-left:22px}
  li{margin:0 0 4px}
  strong{color:#1F1B16}
  a{color:#6C63FF}
  .highlight{background:#FBF1E4;border-radius:12px;padding:16px 20px;margin:12px 0}
  .footer{color:#A39A8C;font-size:12px;margin-top:40px;text-align:center;border-top:1px solid #EFE4D2;padding-top:20px}
  @media(max-width:540px){.wrap{padding:32px 20px}}
`;

function legalPage(title: string, body: string): Response {
  const html = `<!DOCTYPE html><html lang="en"><head>
<meta charset="utf-8"><title>${title} — Milo</title>
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>${STYLE}</style>
</head><body><div class="wrap">
${body}
<p class="footer">Milo · <a href="/privacy">Privacy Policy</a> · <a href="/terms">Terms of Service</a> · <a href="mailto:lukaspock.dev@gmail.com">Contact</a></p>
</div></body></html>`;
  return new Response(html, { headers: { "Content-Type": "text/html; charset=utf-8" } });
}

export function privacyPolicy(): Response {
  return legalPage("Privacy Policy", `
<h1>Privacy Policy</h1>
<p class="sub">Last updated: <strong>June 7, 2026</strong> · Effective immediately upon posting</p>

<p>Milo ("we", "our", or "us") is committed to protecting your privacy. This Privacy Policy explains what personal data we collect, how we use it, and your rights under applicable data protection laws including the General Data Protection Regulation (GDPR) and the California Consumer Privacy Act (CCPA).</p>
<p>By using the Milo app or website, you agree to the practices described in this policy.</p>

<h2>1. Information We Collect</h2>
<p><strong>Account information (provided by you):</strong></p>
<ul>
  <li><strong>Name</strong> — used to identify you within shared calendars.</li>
  <li><strong>Email address</strong> — used for account authentication, email verification, and optional notifications.</li>
  <li><strong>Password</strong> — stored only as a one-way bcrypt hash. We never store or have access to your plain-text password.</li>
  <li><strong>Profile photo</strong> (optional) — uploaded by you and stored on Cloudinary.</li>
  <li><strong>Profile color</strong> (optional) — a display preference you choose.</li>
</ul>

<p><strong>Content you create:</strong></p>
<ul>
  <li>Calendar names, event titles, descriptions, dates, icons, and emoji reactions.</li>
  <li>Event photos uploaded to shared calendars.</li>
  <li>Poll titles and options.</li>
</ul>

<p><strong>Third-party account data (optional):</strong></p>
<ul>
  <li>If you connect <strong>Google Sign-In</strong>, we receive your Google account ID, name, and email from Google.</li>
  <li>If you connect <strong>Google Calendar sync</strong>, we store encrypted OAuth tokens to access your Google Calendar on your behalf. We only read and write events — we never access other Google data.</li>
</ul>

<p><strong>Device data (optional):</strong></p>
<ul>
  <li>If you enable device calendar sync, we read events from your device's local calendar app and, with your consent, share them with other members of your calendar. We access your camera and photo library only when you explicitly choose to upload a photo.</li>
</ul>

<p><strong>Usage and technical data:</strong></p>
<ul>
  <li>Authentication tokens (JWT) stored locally on your device via app storage.</li>
  <li>Standard server logs (request timestamps, IP addresses) retained by our hosting provider for operational purposes. We do not use these for profiling.</li>
</ul>

<h2>2. How We Use Your Information</h2>
<ul>
  <li><strong>Provide the service</strong> — authenticate you, display your calendars and events, and enable sharing with invited members.</li>
  <li><strong>Transactional emails</strong> — send email verification, password reset, event notifications, and event reminders. You can adjust notification preferences in the app at any time.</li>
  <li><strong>Google Calendar sync</strong> — mirror events between Milo and your personal Google Calendar, only if you explicitly connect this feature.</li>
  <li><strong>Device calendar sync</strong> — share your device calendar events with co-members of a shared calendar, only if you enable this feature.</li>
  <li><strong>Improve reliability</strong> — use server logs to diagnose errors and maintain uptime.</li>
</ul>
<p>We do <strong>not</strong> sell your data, use it for advertising, or share it with third parties for marketing purposes.</p>

<h2>3. Legal Basis for Processing (GDPR)</h2>
<p>If you are located in the European Economic Area (EEA), we process your personal data under the following legal bases:</p>
<ul>
  <li><strong>Performance of a contract</strong> — processing necessary to provide the Milo service you have requested (Art. 6(1)(b) GDPR).</li>
  <li><strong>Legitimate interests</strong> — server logging and security monitoring to maintain a secure, functional service (Art. 6(1)(f) GDPR).</li>
  <li><strong>Consent</strong> — optional features such as Google Calendar sync and device calendar sharing, which you may withdraw at any time (Art. 6(1)(a) GDPR).</li>
</ul>

<h2>4. Third-Party Service Providers</h2>
<p>We share data with the following sub-processors solely to operate the service:</p>
<div class="highlight">
<ul>
  <li><strong>Render.com</strong> (United States) — cloud hosting and PostgreSQL database. <a href="https://render.com/privacy" target="_blank">Privacy Policy</a></li>
  <li><strong>Cloudinary</strong> (United States) — storage and delivery of user-uploaded photos and event icons. <a href="https://cloudinary.com/privacy" target="_blank">Privacy Policy</a></li>
  <li><strong>Google LLC</strong> (United States) — Google Sign-In and optional Google Calendar API integration. <a href="https://policies.google.com/privacy" target="_blank">Privacy Policy</a></li>
  <li><strong>Gmail API / Google Workspace</strong> — used to send transactional emails from our sending account.</li>
</ul>
</div>
<p>We do not use Google Analytics, Facebook Pixel, or any other advertising or analytics platform.</p>

<h2>5. International Data Transfers</h2>
<p>Our service is hosted in the United States. If you access Milo from the EEA, Switzerland, or the United Kingdom, your data is transferred to and processed in the US. We rely on Standard Contractual Clauses (SCCs) and the data processing agreements of our sub-processors (Render.com, Cloudinary, Google) to ensure adequate protection for such transfers.</p>

<h2>6. Data Retention</h2>
<p>We retain your personal data for as long as your account is active. If you delete your account, all associated data — including your profile, calendars, events, photos, and OAuth tokens — is permanently and irreversibly deleted from our systems within 30 days. Server access logs are retained by Render.com for up to 30 days in accordance with their data retention policy.</p>

<h2>7. Your Rights</h2>
<p>Depending on your location, you may have the following rights regarding your personal data:</p>
<ul>
  <li><strong>Access</strong> — request a copy of the personal data we hold about you.</li>
  <li><strong>Rectification</strong> — correct inaccurate or incomplete data (you can update your name, email, and profile photo directly in the app).</li>
  <li><strong>Erasure ("right to be forgotten")</strong> — delete your account and all associated data at any time via the app's home screen.</li>
  <li><strong>Restriction</strong> — request that we limit processing of your data in certain circumstances.</li>
  <li><strong>Portability</strong> — receive your data in a structured, machine-readable format.</li>
  <li><strong>Objection</strong> — object to processing based on legitimate interests.</li>
  <li><strong>Withdraw consent</strong> — disconnect Google Calendar sync or device calendar access at any time in the app settings.</li>
</ul>
<p>To exercise any of these rights, contact us at <a href="mailto:lukaspock.dev@gmail.com">lukaspock.dev@gmail.com</a>. We will respond within 30 days.</p>
<p>If you are in the EEA, you also have the right to lodge a complaint with your local data protection authority.</p>

<h2>8. California Privacy Rights (CCPA)</h2>
<p>If you are a California resident, you have the right to know what personal information we collect, request deletion of your personal information, and opt out of the sale of personal information. <strong>We do not sell personal information.</strong> To exercise your CCPA rights, contact us at <a href="mailto:lukaspock.dev@gmail.com">lukaspock.dev@gmail.com</a>.</p>

<h2>9. Children's Privacy (COPPA)</h2>
<p>Milo is not directed to children under the age of 13. We do not knowingly collect personal information from children under 13. If you believe a child under 13 has provided us with personal data, please contact us and we will delete it promptly.</p>

<h2>10. Security</h2>
<p>We take reasonable technical and organisational measures to protect your data:</p>
<ul>
  <li>Passwords are hashed using <strong>bcrypt</strong> and are never stored or transmitted in plain text.</li>
  <li>All data in transit is encrypted via <strong>HTTPS/TLS</strong>.</li>
  <li>Google OAuth tokens stored in our database are encrypted using AES-256.</li>
  <li>Authentication uses short-lived <strong>JWT tokens</strong> stored only on your device.</li>
</ul>
<p>No method of transmission over the internet is 100% secure. We cannot guarantee absolute security but we are committed to protecting your data using industry-standard practices.</p>

<h2>11. Changes to This Policy</h2>
<p>We may update this Privacy Policy from time to time. When we make material changes, we will update the "Last updated" date at the top of this page. We encourage you to review this policy periodically. Your continued use of the service after any changes constitutes acceptance of the updated policy.</p>

<h2>12. Contact Us</h2>
<p>If you have questions, concerns, or requests regarding this Privacy Policy, please contact us:</p>
<div class="highlight">
  <p style="margin:0"><strong>Milo</strong><br>
  Email: <a href="mailto:lukaspock.dev@gmail.com">lukaspock.dev@gmail.com</a></p>
</div>
`);
}

export function termsOfService(): Response {
  return legalPage("Terms of Service", `
<h1>Terms of Service</h1>
<p class="sub">Last updated: <strong>June 7, 2026</strong> · Effective immediately upon posting</p>

<p>Please read these Terms of Service ("Terms") carefully before using the Milo application or website operated by Milo ("we", "us", or "our"). By accessing or using the Service, you agree to be bound by these Terms. If you disagree with any part of the Terms, do not use the Service.</p>

<h2>1. Acceptance of Terms</h2>
<p>By creating an account or using Milo in any way, you confirm that you are at least 13 years of age, have read and understood these Terms, and agree to be legally bound by them. If you are using Milo on behalf of an organisation, you represent that you have authority to bind that organisation to these Terms.</p>

<h2>2. Description of Service</h2>
<p>Milo is a shared calendar application that allows users to create calendars, invite members, create and manage events, upload photos, react to events, participate in scheduling polls, and optionally sync events with Google Calendar and device calendar apps. The Service is provided as-is and may be updated, modified, or discontinued at any time.</p>

<h2>3. Account Registration</h2>
<ul>
  <li>You must provide accurate, current, and complete information when creating an account.</li>
  <li>You are solely responsible for maintaining the confidentiality of your login credentials.</li>
  <li>You are responsible for all activity that occurs under your account.</li>
  <li>You must notify us immediately at <a href="mailto:lukaspock.dev@gmail.com">lukaspock.dev@gmail.com</a> if you suspect any unauthorised use of your account.</li>
  <li>You may not create more than one account per person, or create an account on behalf of someone else without their consent.</li>
</ul>

<h2>4. Acceptable Use</h2>
<p>You agree not to use the Service to:</p>
<ul>
  <li>Violate any applicable local, national, or international law or regulation.</li>
  <li>Upload, transmit, or share content that is unlawful, harmful, threatening, abusive, harassing, defamatory, obscene, or otherwise objectionable.</li>
  <li>Impersonate any person or entity or misrepresent your affiliation with any person or entity.</li>
  <li>Attempt to gain unauthorised access to any part of the Service, other accounts, or systems connected to the Service.</li>
  <li>Interfere with or disrupt the integrity or performance of the Service or third-party data contained therein.</li>
  <li>Use automated means (bots, scrapers, crawlers) to access, collect, or index any data from the Service without our express written consent.</li>
  <li>Use the Service for any commercial purpose without our prior written consent.</li>
</ul>

<h2>5. User Content</h2>
<p>You retain full ownership of the content you submit to the Service, including calendar names, event titles, descriptions, and uploaded photos ("User Content"). By submitting User Content, you grant Milo a limited, non-exclusive, royalty-free, worldwide licence to store, display, and transmit your User Content solely for the purpose of operating and providing the Service to you and your calendar members.</p>
<p>You represent and warrant that:</p>
<ul>
  <li>You own or have the necessary rights to the User Content you submit.</li>
  <li>Your User Content does not infringe the intellectual property rights, privacy rights, or any other rights of any third party.</li>
  <li>Your User Content complies with these Terms and all applicable laws.</li>
</ul>
<p>We reserve the right to remove any User Content that violates these Terms, at our sole discretion and without prior notice.</p>

<h2>6. Privacy</h2>
<p>Your use of the Service is also governed by our <a href="/privacy">Privacy Policy</a>, which is incorporated into these Terms by reference. By using the Service, you consent to the collection and use of your data as described in the Privacy Policy.</p>

<h2>7. Third-Party Services</h2>
<p>The Service integrates with third-party services including Google Sign-In, Google Calendar API, and Cloudinary. Your use of these integrations is subject to the respective third parties' terms of service and privacy policies. We are not responsible for the practices or content of any third-party services.</p>

<h2>8. Intellectual Property</h2>
<p>The Service and its original content (excluding User Content), features, and functionality are and will remain the exclusive property of Milo and its licensors. Our trademarks, trade dress, and logo may not be used in connection with any product or service without our prior written consent. Nothing in these Terms grants you any right to use Milo's name, logo, or branding.</p>

<h2>9. Availability and Service Changes</h2>
<p>We strive to maintain reliable service but do not guarantee uninterrupted or error-free availability. The Service is hosted on a free-tier cloud infrastructure (Render.com), which may result in periods of inactivity or slow response times. We reserve the right to modify, suspend, or discontinue any part of the Service at any time with or without notice. We will not be liable to you or any third party for any modification, suspension, or discontinuation.</p>

<h2>10. Disclaimers</h2>
<p>THE SERVICE IS PROVIDED ON AN "AS IS" AND "AS AVAILABLE" BASIS WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND NON-INFRINGEMENT. WE DO NOT WARRANT THAT THE SERVICE WILL BE UNINTERRUPTED, SECURE, OR ERROR-FREE, OR THAT DEFECTS WILL BE CORRECTED.</p>

<h2>11. Limitation of Liability</h2>
<p>TO THE FULLEST EXTENT PERMITTED BY APPLICABLE LAW, MILO AND ITS OPERATORS SHALL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES — INCLUDING LOSS OF PROFITS, DATA, GOODWILL, OR OTHER INTANGIBLE LOSSES — ARISING OUT OF OR IN CONNECTION WITH YOUR ACCESS TO OR USE OF (OR INABILITY TO ACCESS OR USE) THE SERVICE, EVEN IF WE HAVE BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.</p>
<p>OUR TOTAL CUMULATIVE LIABILITY TO YOU FOR ANY CLAIMS ARISING OUT OF OR RELATED TO THESE TERMS OR THE SERVICE SHALL NOT EXCEED THE GREATER OF (A) THE AMOUNT YOU PAID TO USE THE SERVICE IN THE 12 MONTHS PRECEDING THE CLAIM, OR (B) €100.</p>

<h2>12. Indemnification</h2>
<p>You agree to defend, indemnify, and hold harmless Milo and its operators from and against any claims, liabilities, damages, judgments, awards, losses, costs, expenses, or fees (including reasonable legal fees) arising out of or relating to your violation of these Terms or your use of the Service, including but not limited to your User Content, your use of any Service content, or any activity conducted through your account.</p>

<h2>13. Termination</h2>
<p>You may delete your account at any time from the app's home screen, which terminates your use of the Service and triggers permanent deletion of your data. We reserve the right to suspend or terminate your access to the Service immediately, without prior notice or liability, for any reason, including if you breach these Terms. Upon termination, your right to use the Service ceases immediately. All provisions of these Terms that by their nature should survive termination will survive.</p>

<h2>14. Governing Law and Dispute Resolution</h2>
<p>These Terms shall be governed by and construed in accordance with the laws of Austria, without regard to its conflict of law provisions. Any dispute arising from or relating to these Terms or the Service shall first be attempted to be resolved through good-faith negotiation. If resolution cannot be reached informally, disputes shall be subject to the exclusive jurisdiction of the competent courts of Austria. If you are a consumer in the European Union, you may also be entitled to use the EU Online Dispute Resolution platform at <a href="https://ec.europa.eu/consumers/odr" target="_blank">ec.europa.eu/consumers/odr</a>.</p>

<h2>15. Severability</h2>
<p>If any provision of these Terms is held to be invalid, illegal, or unenforceable, the remaining provisions will continue in full force and effect. The invalid or unenforceable provision will be modified to the minimum extent necessary to make it valid and enforceable.</p>

<h2>16. Entire Agreement</h2>
<p>These Terms, together with our Privacy Policy, constitute the entire agreement between you and Milo regarding the Service and supersede all prior and contemporaneous understandings, agreements, representations, and warranties.</p>

<h2>17. Changes to These Terms</h2>
<p>We reserve the right to modify these Terms at any time. When we make material changes, we will update the "Last updated" date at the top of this page. Your continued use of the Service after any changes constitutes your acceptance of the new Terms. We encourage you to review these Terms periodically.</p>

<h2>18. Contact Us</h2>
<p>If you have any questions about these Terms, please contact us:</p>
<div class="highlight">
  <p style="margin:0"><strong>Milo</strong><br>
  Email: <a href="mailto:lukaspock.dev@gmail.com">lukaspock.dev@gmail.com</a></p>
</div>
`);
}
