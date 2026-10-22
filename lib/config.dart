// Supabase project "TransWell" (ap-south-1). The anon key is public by design:
// every table is protected by row-level security on the server.
const supabaseUrl = 'https://toouzmbhlltipjjcyqim.supabase.co';
const supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRvb3V6bWJobGx0aXBqamN5cWltIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI2NTMxMDMsImV4cCI6MjEwODIyOTEwM30.mcSgMwm8zDsHrHsTf6pnCVWdP3iKIfk8u_aDioV4lt4';

/// Domain used to turn a phone number into a login id (phone@domain).
const phoneLoginDomain = 'phone.transwell.app';

/// Link sent in WhatsApp invites. The GitHub repo is private, so replace this
/// with the Play Store link (or another public download page) before inviting.
const appDownloadLink = 'https://github.com/spywellinfotech-sys/TransWell/releases/latest';
