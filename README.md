# TransWell

Transport commission agents ke liye Android app (Flutter): trips, party / truck owner ka hisaab, bilty, directory, load board, live tracking — aur truck owner, driver, shipper ke liye alag screens.

## Abhi kya hai (prototype v0.1)

- Login (demo OTP) → "Aap kaun hain" → role ke hisaab se home
- **Agent:** home dashboard, trip list + search/filter, naya trip (commission apne aap), trip detail + status, payment entry, party ledger, bilty preview, directory, load board, load post, live tracking map
- **Truck owner:** gaadiyan, agents se kitna lena hai, "gaadi khaali hai — post karo"
- **Driver (Hindi):** location permission, aaj ka trip, loaded / pahunch gaya, paas ke loads
- **Shipper:** mera maal kahan hai, bilty / POD, hisaab, load post

Data abhi sample hai aur phone pe hi rehta hai (app band karne pe reset). Asli SMS OTP, Supabase database, GPS tracking, PDF / WhatsApp share aur notifications agle stages mein.

## APK kaise milta hai

`main` branch pe har push pe GitHub Actions APK banata hai aur **Releases** mein daal deta hai: https://github.com/spywellinfotech-sys/TransWell/releases/latest

Android project (`android/`) build ke waqt `flutter create` se banta hai, isliye repo mein sirf `lib/` aur `pubspec.yaml` hain.
