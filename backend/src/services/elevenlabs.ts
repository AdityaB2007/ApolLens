// Indi: ElevenLabs integration for spoken instructions and cached audio.
import axios from 'axios';


// Get API key from the .env 
const ELEVENLABS_API_KEY = process.env.ELEVENLABS_API_KEY;
const VOICE_ID = process.env.ELEVENLABS_VOICE_ID || '21m00Tcm4TlvDq8ikWAM'; // Default voice (Rachel)

export const generateSpeech = async (text: string): Promise<Buffer> => {
    try {
        const response = await axios.post(
            `https://api.elevenlabs.io/v1/text-to-speech/${VOICE_ID}`,
            {
                text: text,
                model_id: 'eleven_flash_v2_5',
            },
            {
                headers: {
                    'Accept': 'audio/mpeg',
                    'xi-api-key': ELEVENLABS_API_KEY,
                    'Content-Type': 'application/json',
                },
                responseType: 'arraybuffer', // !!!for receiving binary audio data!!!!
            }
        );

        return Buffer.from(response.data);
    } catch (error: any) {
        console.error('ElevenLabs API Error:', error.response?.data ? Buffer.from(error.response.data).toString() : error.message);
        throw new Error('Failed to generate audio');
    }
};