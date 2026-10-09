/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
      './app/views/**/*.html.erb',
      './app/views/**/*.turbo_stream.erb',
      './app/helpers/**/*.rb',
      './app/frontend/**/*.{js,ts,jsx,tsx}',
  ],
  safelist: [
    // Dynamic classes in recommendation cards (can't be detected statically)
    'border-orange-300', 'ring-2', 'ring-orange-300',
    'border-gray-200',
    'bg-gradient-to-r', 'from-orange-400', 'to-yellow-400',
    'from-gray-100', 'to-gray-200',
    'text-orange-900', 'text-white', 'text-gray-800', 'text-gray-500',
    'gap-5',
    'animate-fade-out',
  ],
  theme: {
    extend: {
      keyframes: {
        'fade-out': {
          '0%': { opacity: '1', transform: 'translateX(-50%) translateY(0)' },
          '100%': { opacity: '0', transform: 'translateX(-50%) translateY(-20px)' },
        }
      },
      animation: {
        'fade-out': 'fade-out 0.5s ease-out forwards',
      }
    },
  },
  plugins: [
      require('@tailwindcss/forms'),
  ],
}

