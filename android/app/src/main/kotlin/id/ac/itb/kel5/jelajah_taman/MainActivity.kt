package id.ac.itb.kel5.jelajah_taman

import com.ryanheise.audioservice.AudioServiceActivity

// F04: audio_service's activity shares one Flutter engine with the media service, so the
// lock-screen / earphone controls reach the running app (audio module, ARCHITECTURE §5).
class MainActivity : AudioServiceActivity()
