#!/usr/bin/env bash
# bloodborne-ios: one gameplay measurement on the iPhone. Writes the app's
# Documents/bbport.ini, launches the game with its live log, presses Cross until gameplay loads
# (the copied Mac save, Documents/mac-save), measures, prints the FPS and the longest Metal command
# buffers, and stops the app.
#   BB_IOS_DEVICE=<udid> scripts/trial.sh NAME 'INI LINES (\n-separated)' ['"ENV":"VALUE",...']
# KEEP=1 leaves the game running (for a Time Profiler trace); MEASURE=seconds (40); TARGETS=1
# counts the calls into the translator (BB_RECOMP_TARGETS). The log: out/logs/trial-NAME.log.
set -u
cd "$(dirname "$0")/.."
export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
U=${BB_IOS_DEVICE:?the iPhone UDID (xcrun devicectl list devices)}
A=${BB_IOS_BUNDLE:-io.github.pablovsouza.bloodborne-poc}
name=$1 ini=$2 extra=${3:-}
mkdir -p out/logs
L=out/logs/trial-$name.log
printf '%b' "$ini" > out/logs/trial.ini
xcrun devicectl device copy to --device "$U" --domain-type appDataContainer --domain-identifier "$A" \
    --source out/logs/trial.ini --destination Documents/bbport.ini >/dev/null 2>&1
ENV="{\"BB_IOS_PROBE_ONLY\":\"0\",\"BB_IOS_METAL_TEST\":\"0\",\"BB_IOS_FILE_TEST\":\"0\",\"BB_IOS_GUARD_TEST\":\"0\",\"BB_IOS_CPU_ONLY\":\"0\",\"BB_IOS_SAVE\":\"mac-save\",\"BB_RECOMP_TARGETS\":\"${TARGETS:-0}\",\"MTL_HUD_ENABLED\":\"0\",\"BB_LOG_LONG_CB_MS\":\"25\"${extra:+,$extra}}"
# A console session still attached to an earlier run keeps writing to its log (a NUL gap, then
# "The app terminated" when this launch ends that app): end it, and start from a new file.
pkill -f "devicectl device process launch --device $U" 2>/dev/null; rm -f "$L"
(xcrun devicectl device process launch --device "$U" --terminate-existing --console --environment-variables "$ENV" "$A" > "$L" 2>&1 &)
end=$((SECONDS + 150))
until (( SECONDS > end )) || [[ $(grep -ac "Frame stats" "$L" 2>/dev/null) -ge 3 ]]; do sleep 3; done
for _ in $(seq 1 12); do
    BB_IOS_DEVICE=$U bash scripts/press.sh cross 0.3; sleep 5
    d=$(grep -a "Frame stats" "$L" | tail -1 | grep -o "[0-9]* draws/frame"); [[ ${d%% *} -gt 500 ]] && break
    grep -aq "terminated" "$L" && break
done
# The test banner counts down to the end of the measurement (Documents/test.clock).
echo $(( $(date +%s) + ${MEASURE:-40} )) > out/logs/test.clock
xcrun devicectl device copy to --device "$U" --domain-type appDataContainer --domain-identifier "$A" \
    --source out/logs/test.clock --destination Documents/test.clock >/dev/null 2>&1
start=$(grep -ac "Frame stats" "$L"); sleep "${MEASURE:-40}"
echo "== $name"
grep -a "Frame stats" "$L" | tail -n +$((start + 2)) | grep -o "^Frame stats: [0-9.]* FPS\|[0-9]* draws/frame" | paste - - | tail -4
echo "long command buffers: $(grep -ac "Metal command buffer" "$L")"
grep -a "Metal command buffer" "$L" | tail -3 | cut -c1-220
grep -aE "terminated|Assertion|Host fault" "$L" | head -2
if [[ -z ${KEEP:-} ]]; then
    pid=$(xcrun devicectl device info processes --device "$U" 2>/dev/null | grep -i BloodbornePoC | awk '{print $1}' | head -1)
    [[ -n $pid ]] && xcrun devicectl device process terminate --device "$U" --pid "$pid" >/dev/null 2>&1
fi
