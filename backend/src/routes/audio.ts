// Indi: API routes for generating and retrieving spoken instructions.
import { Router, Request, Response } from 'express';
import { generateSpeech } from '../services/elevenlabs';

const router = Router();

// POST /api/audio/speak
router.post('/speak', async (req: Request, res: Response) => {
    const { text } = req.body;

    if (!text) {
        return res.status(400).json({ error: 'Text is required to generate speech.' });
    }

    try {
        // Call the ElevenLabs service we created
        const audioBuffer = await generateSpeech(text);
        
        // Send the audio file back to the client
        res.set({
            'Content-Type': 'audio/mpeg',
            'Content-Length': audioBuffer.length.toString(),
        });
        res.send(audioBuffer);
    } catch (error) {
        res.status(500).json({ error: 'Failed to generate audio.' });
    }
});

export default router;