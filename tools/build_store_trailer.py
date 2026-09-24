"""Encode the captured game-camera frames with the game's ambient sound beds.

Requires FFmpeg. Frames are rendered by capture_store_media.gd at fixed 30 fps.
No generated scenery, frame interpolation, stock footage or external music.
"""
from pathlib import Path
import argparse
import json
import subprocess

ROOT = Path(__file__).resolve().parents[1]
MEDIA = ROOT / 'docs/quest-store/media'
SHOTS = ['lake_pier', 'gray_pier', 'cedar_creek', 'glacier_run', 'blouberg_sunrise_2']


def run(args):
    subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', *args], check=True)


def encode(frames, work):
    work.mkdir(parents=True, exist_ok=True)
    common = ['-c:v', 'libx264', '-preset', 'medium', '-crf', '18',
              '-pix_fmt', 'yuv420p', '-r', '30', '-threads', '2',
              '-c:a', 'aac', '-b:a', '192k', '-ar', '48000', '-ac', '2',
              '-movflags', '+faststart']
    clips = []
    for name, seconds in [('opening', 2), ('closing', 4)]:
        target = work / f'{name}.mp4'
        run(['-loop', '1', '-framerate', '30', '-i', str(MEDIA / 'trailer-title.png'),
             '-stream_loop', '-1', '-i', str(ROOT / 'assets/audio/ambience/lake_pier.ogg'),
             '-t', str(seconds), '-vf',
             f'fade=t=in:st=0:d=0.3,fade=t=out:st={seconds-.3}:d=0.3',
             '-af', f'volume=0.65,afade=t=in:st=0:d=0.3,afade=t=out:st={seconds-.3}:d=0.3',
             *common, str(target)])
        clips.append(target)
    scenes = []
    for shot in SHOTS:
        files = sorted((frames / shot).glob('*.jpg'))
        if len(files) != 180 or [p.name for p in files] != [f'{i:05d}.jpg' for i in range(180)]:
            raise ValueError(f'{shot}: expected 180 consecutive captured frames')
        target = work / f'{shot}.mp4'
        run(['-framerate', '30', '-start_number', '0', '-i', str(frames / shot / '%05d.jpg'),
             '-stream_loop', '-1', '-i', str(ROOT / f'assets/audio/ambience/{shot}.ogg'),
             '-t', '6', '-vf', 'fade=t=in:st=0:d=0.2,fade=t=out:st=5.8:d=0.2',
             '-af', 'volume=0.65,afade=t=in:st=0:d=0.2,afade=t=out:st=5.8:d=0.2',
             *common, str(target)])
        scenes.append(target)
        print(f'Encoded {shot}', flush=True)
    ordered = [clips[0], *scenes, clips[1]]
    playlist = work / 'clips.txt'
    # Only generated basenames are written, avoiding ffconcat path escaping.
    playlist.write_text(''.join(f"file '{p.name}'\n" for p in ordered))
    run(['-f', 'concat', '-safe', '1', '-i', str(playlist), '-c:v', 'copy',
         '-af', 'loudnorm=I=-20:TP=-2:LRA=9', '-c:a', 'aac', '-b:a', '192k',
         '-ar', '48000', '-ac', '2',
         '-movflags', '+faststart', str(MEDIA / 'trailer.mp4')])
    probe = subprocess.check_output(['ffprobe', '-v', 'error', '-show_streams',
                                    '-show_format', '-of', 'json', str(MEDIA / 'trailer.mp4')], text=True)
    info = json.loads(probe)
    video = next(s for s in info['streams'] if s['codec_type'] == 'video')
    audio = next(s for s in info['streams'] if s['codec_type'] == 'audio')
    assert (video['width'], video['height']) == (1920, 1080)
    assert video['codec_name'] == 'h264' and audio['codec_name'] == 'aac'
    assert video['r_frame_rate'] == '30/1'
    assert 35.9 <= float(info['format']['duration']) <= 36.5
    info['format']['filename'] = 'trailer.mp4'
    (MEDIA / 'trailer-probe.json').write_text(json.dumps(info, indent=2) + '\n')
    print('Verified 36-second 1080p/30 H.264 + AAC trailer.', flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--frames', type=Path, default=Path('/tmp/ubs-trailer-frames'))
    parser.add_argument('--work', type=Path, default=ROOT / 'builds/store-media')
    options = parser.parse_args()
    encode(options.frames.resolve(), options.work.resolve())
