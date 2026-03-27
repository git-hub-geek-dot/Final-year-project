const cloudinary = require('cloudinary').v2;
const { CloudinaryStorage } = require('multer-storage-cloudinary');

// Configure Cloudinary
cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
});

// Create storage engine
const storage = new CloudinaryStorage({
  cloudinary: cloudinary,
  params: {
    folder: 'volunteerx-uploads',
    allowed_formats: ['jpg', 'jpeg', 'png', 'webp'],
    transformation: [
      { width: 1000, height: 1000, crop: 'limit' }, // Max dimensions
      { quality: 'auto' } // Automatic quality optimization
    ],
    public_id: (req, file) => {
      // Generate unique filename with timestamp
      return `upload_${Date.now()}_${Math.random().toString(36).substring(2, 15)}`;
    },
  },
});

module.exports = {
  cloudinary,
  storage
};