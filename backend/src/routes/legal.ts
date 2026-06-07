const STYLE = `
  *{box-sizing:border-box}
  body{margin:0;background:#FFF8F0;font-family:'Helvetica Neue',Arial,sans-serif;padding:40px 24px}
  .wrap{max-width:680px;margin:0 auto;background:#fff;border-radius:24px;border:2px solid #EFE4D2;padding:48px 40px;box-shadow:0 4px 0 #EFE4D2}
  h1{font-size:28px;font-weight:800;color:#1F1B16;margin:0 0 4px}
  .sub{color:#A39A8C;font-size:13px;margin:0 0 32px}
  h2{font-size:16px;font-weight:700;color:#1F1B16;margin:28px 0 6px}
  p,li{font-size:14px;color:#4A4035;line-height:1.7;margin:0 0 8px}
  ul{margin:0 0 8px;padding-left:20px}
  .footer{color:#A39A8C;font-size:12px;margin-top:40px;text-align:center}
  @media(max-width:540px){.wrap{padding:32px 20px}}
`;

function legalPage(title: string, body: string): Response {
  const html = `<!DOCTYPE html><html><head>
<meta charset="utf-8"><title>${title} — Milo</title>
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>${STYLE}</style>
</head><body><div class="wrap">
${body}
<p class="footer">Milo · <a href="/privacy" style="color:#6C63FF">Privacy Policy</a> · <a href="/terms" style="color:#6C63FF">Terms of Service</a></p>
</div></body></html>`;
  return new Response(html, { headers: { "Content-Type": "text/html" } });
}

export function privacyPolicy(): Response {
  return legalPage("Privacy Policy", `
<h1>Privacy Policy</h1>
<p class="sub">Last updated: June 2025</p>

<h2>1. What we collect</h2>
<p>When you create an account we collect your <strong>name</strong>, <strong>email address</strong>, and a hashed password (or a Google account identifier if you use Google Sign-In). When you create calendar events we store the <strong>title</strong>, <strong>description</strong>, <strong>start and end times</strong>, and <strong>color</strong> you provide.</p>

<h2>2. How we use your data</h2>
<ul>
  <li>To authenticate you and keep your session secure.</li>
  <li>To display your calendars and events to you and the members you share them with.</li>
  <li>To send you email notifications about new events (if you opt in).</li>
  <li>To sync events to your personal Google Calendar (only if you explicitly connect it).</li>
</ul>

<h2>3. Who we share data with</h2>
<p>We do not sell or share your personal data with third parties except:</p>
<ul>
  <li><strong>Google</strong> — for authentication (Google Sign-In) and optional Google Calendar sync, subject to Google's Privacy Policy.</li>
  <li><strong>Render.com</strong> — our hosting provider, which processes data to run the service.</li>
</ul>

<h2>4. Data retention</h2>
<p>Your data is kept for as long as your account exists. You can delete your account at any time from the app's home screen, which permanently removes all your data.</p>

<h2>5. Security</h2>
<p>Passwords are hashed using bcrypt and never stored in plain text. All communication is encrypted via HTTPS/TLS.</p>

<h2>6. Contact</h2>
<p>Questions? Email us at <a href="mailto:lukaspock.dev@gmail.com" style="color:#6C63FF">lukaspock.dev@gmail.com</a>.</p>
`);
}

export function termsOfService(): Response {
  return legalPage("Terms of Service", `
<h1>Terms of Service</h1>
<p class="sub">Last updated: June 2025</p>

<h2>1. Acceptance</h2>
<p>By creating an account or using Milo you agree to these terms. If you do not agree, do not use the service.</p>

<h2>2. Description of service</h2>
<p>Milo is a shared calendar application that lets users create calendars, invite members, manage events, and optionally sync with Google Calendar.</p>

<h2>3. Your account</h2>
<ul>
  <li>You are responsible for keeping your credentials secure.</li>
  <li>You must not use the service for unlawful purposes or to harass others.</li>
  <li>You must be at least 13 years old to use Milo.</li>
</ul>

<h2>4. Content</h2>
<p>You retain ownership of the content you create (calendar names, event titles, etc.). By submitting content you grant Milo a limited licence to store and display it to calendar members as part of operating the service.</p>

<h2>5. Availability</h2>
<p>Milo is provided "as is". We do not guarantee uninterrupted availability, especially on the free hosting tier where the backend may sleep after inactivity.</p>

<h2>6. Termination</h2>
<p>You may delete your account at any time. We reserve the right to suspend or terminate accounts that violate these terms.</p>

<h2>7. Limitation of liability</h2>
<p>To the fullest extent permitted by law, Milo is not liable for any indirect, incidental, or consequential damages arising from your use of the service.</p>

<h2>8. Changes</h2>
<p>We may update these terms from time to time. Continued use of the service after changes constitutes acceptance.</p>

<h2>9. Contact</h2>
<p>Questions? Email us at <a href="mailto:lukaspock.dev@gmail.com" style="color:#6C63FF">lukaspock.dev@gmail.com</a>.</p>
`);
}
