// Indi: Backend API entry point, route registration, and request authentication.
import express, { Request, Response, NextFunction } from 'express';
import dotenv from 'dotenv';
import audioRoutes from './routes/audio';

dotenv.config();

const app = express();
app.use(express.json()); 

//  AUTHENTICATION MIDDLEWARE 
const authenticateToken = (req: Request, res: Response, next: NextFunction) => {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1]; // Expects "Bearer <token>"

    if (!token) {
        return res.status(401).json({ error: 'Access denied. No token provided.' });
    }

    // compare the token to a secret key in our .env file
    if (token !== process.env.API_SECRET_KEY) {
        return res.status(403).json({ error: 'Invalid token.' });
    }

    next(); // If everything is good, proceed
};

// ROUTE REGISTRATION 
// Apply the auth middleware to the audio routes
app.use('/api/audio', authenticateToken, audioRoutes);

// Health check (no auth needed)
app.get('/health', (req, res) => res.status(200).send('API is running'));

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`Server running on http://localhost:${PORT}`);
}); 