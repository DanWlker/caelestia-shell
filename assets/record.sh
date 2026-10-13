#!/usr/bin/env bash
# Fork: screen recording with wf-recorder, replacing `caelestia record` (gpu-screen-recorder has no
# GPU encoder to use on Asahi). Used by services/Recorder.qml.
#   record.sh start [-r] [-s]   -r: pick a region with slurp, -s: record desktop audio
#   record.sh stop              stop, save to the recordings folder, notify
# wf-recorder can't pause, so there is no pause command.

state=${XDG_STATE_HOME:-$HOME/.local/state}/caelestia/record
tmp=$state/recording.mp4
recordings=${CAELESTIA_RECORDINGS_DIR:-${XDG_VIDEOS_DIR:-$HOME/Videos}/Recordings}

start() {
	local region= sound=
	for arg in "$@"; do
		case $arg in
		-r) region=1 ;;
		-s) sound=1 ;;
		-sr | -rs) region=1 sound=1 ;;
		esac
	done

	local args=()
	if [ -n "$region" ]; then
		geometry=$(slurp) || exit 0 # cancelled
		args+=(-g "$geometry")
	else
		# Focused monitor, from "workspace ID 1 (1) on monitor DP-1:"
		monitor=$(hyprctl activeworkspace | sed -n 's/.* on monitor \(.*\):$/\1/p')
		args+=(-o "$monitor")
	fi
	if [ -n "$sound" ]; then
		# Desktop audio: the default sink's monitor (through pipewire-pulse)
		sink=$(wpctl inspect @DEFAULT_AUDIO_SINK@ | sed -n 's/.*node\.name = "\(.*\)"/\1/p')
		args+=(--audio="$sink.monitor")
	fi

	mkdir -p "$state"
	rm -f "$tmp"
	setsid -f wf-recorder "${args[@]}" -f "$tmp" </dev/null >/dev/null 2>"$state/wf-recorder.log"

	sleep 1
	if pidof -q wf-recorder; then
		notify-send -a caelestia -p "Recording started" "Recording..." >"$state/notif-id"
	else
		notify-send -a caelestia -u critical "Recording failed" "wf-recorder exited, see $state/wf-recorder.log"
	fi
}

stop() {
	pkill -INT -x wf-recorder
	# Wait for wf-recorder to finish writing, or the file is corrupted
	while pidof -q wf-recorder; do sleep 0.1; done

	if [ -s "$state/notif-id" ]; then
		gdbus call --session --dest org.freedesktop.Notifications --object-path /org/freedesktop/Notifications \
			--method org.freedesktop.Notifications.CloseNotification "$(cat "$state/notif-id")" >/dev/null
		rm -f "$state/notif-id"
	fi
	[ -s "$tmp" ] || exit 0

	mkdir -p "$recordings"
	path=$recordings/recording_$(date +%Y%m%d_%H-%M-%S).mp4
	mv "$tmp" "$path"

	# Detached, so the notification's actions outlive this script
	setsid -f sh -c '
		action=$(notify-send -a caelestia --action=watch=Watch --action=open=Open --action=delete=Delete \
			"Recording stopped" "Recording saved in $1") || exit 0
		case $action in
		watch) exec xdg-open "$1" ;;
		open) exec xdg-open "$(dirname "$1")" ;;
		delete) rm -f -- "$1" ;;
		esac
	' sh "$path" </dev/null >/dev/null 2>&1
}

case $1 in
start) shift && start "$@" ;;
stop) stop ;;
*) echo "usage: $0 start [-r] [-s] | stop" >&2 && exit 1 ;;
esac
