"""Adds the permissions and intent queries TransWell needs to the generated
Android manifest. Safe to run more than once."""
import re
import sys

path = sys.argv[1] if len(sys.argv) > 1 else "android/app/src/main/AndroidManifest.xml"
xml = open(path, encoding="utf-8").read()

perms = [
    "android.permission.INTERNET",
    "android.permission.ACCESS_FINE_LOCATION",
    "android.permission.ACCESS_COARSE_LOCATION",
    "android.permission.READ_CONTACTS",
]
for p in perms:
    if p not in xml:
        xml = xml.replace("<application", f'<uses-permission android:name="{p}"/>\n    <application', 1)

queries = """
    <queries>
        <intent><action android:name="android.intent.action.DIAL" /><data android:scheme="tel" /></intent>
        <intent><action android:name="android.intent.action.VIEW" /><data android:scheme="tel" /></intent>
        <intent><action android:name="android.intent.action.VIEW" /><data android:scheme="https" /></intent>
        <intent><action android:name="android.intent.action.SEND" /><data android:mimeType="*/*" /></intent>
        <intent><action android:name="android.intent.action.PROCESS_TEXT" /><data android:mimeType="text/plain" /></intent>
    </queries>
"""
if 'android:scheme="tel"' not in xml:
    if "<queries>" in xml:
        xml = re.sub(r"<queries>.*?</queries>", queries.strip(), xml, count=1, flags=re.S)
    else:
        xml = xml.replace("</manifest>", queries + "</manifest>", 1)

xml = re.sub(r'android:label="[^"]*"', 'android:label="TransWell"', xml, count=1)
open(path, "w", encoding="utf-8").write(xml)
print("patched", path)

# Launch (before Flutter draws) in the logo's navy instead of white.
import os
res = os.path.join(os.path.dirname(path), "res")
for folder in ("drawable", "drawable-v21"):
    f = os.path.join(res, folder, "launch_background.xml")
    if os.path.exists(f):
        open(f, "w", encoding="utf-8").write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            '<layer-list xmlns:android="http://schemas.android.com/apk/res/android">\n'
            '    <item><color android:color="#0B2A6B"/></item>\n'
            '</layer-list>\n')
        print("launch background", f)
