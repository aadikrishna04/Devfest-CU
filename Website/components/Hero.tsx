export function Hero() {
  return (
    <>
      {/* Team names at top - alphabetical, linked to LinkedIn */}
      <div className="w-full py-3 px-6 sm:px-12 bg-white dark:bg-gray-950">
        <div className="max-w-6xl mx-auto flex flex-wrap justify-between items-center gap-y-3 text-lg md:text-xl text-gray-500 dark:text-gray-400" style={{ fontFamily: 'Times New Roman, serif' }}>
          <a href="https://www.linkedin.com/in/aaditkrishna/" target="_blank" rel="noopener noreferrer" className="hover:text-[#D4594D] dark:hover:text-[#EB9E94] transition-colors">Aadit Krishna</a>
          <a href="https://www.linkedin.com/in/ansh-krishna/" target="_blank" rel="noopener noreferrer" className="hover:text-[#D4594D] dark:hover:text-[#EB9E94] transition-colors">Ansh Krishna</a>
          <a href="https://www.linkedin.com/in/armaan-agraw/" target="_blank" rel="noopener noreferrer" className="hover:text-[#D4594D] dark:hover:text-[#EB9E94] transition-colors">Armaan Agrawal</a>
          <a href="https://www.linkedin.com/in/jonathanwang10/" target="_blank" rel="noopener noreferrer" className="hover:text-[#D4594D] dark:hover:text-[#EB9E94] transition-colors">Jonathan Wang</a>
        </div>
      </div>

      <section className="relative flex items-center justify-center overflow-hidden bg-white dark:bg-gray-950 pt-8 pb-12 md:pt-12 md:pb-16">
        {/* Animated orb background */}
        <div className="absolute inset-0 flex items-center justify-center opacity-20 dark:opacity-10">
          <div className="w-[600px] h-[600px] rounded-full bg-gradient-to-br from-[#D4594D]/30 to-[#EB9E94]/30 blur-3xl animate-pulse"
               style={{ animationDuration: '4s' }}
          />
        </div>

        {/* Content */}
        <div className="relative z-10 max-w-6xl mx-auto px-6 text-center">
          <div className="mb-4">
            <h1 className="text-5xl md:text-6xl tracking-tight mb-3 text-gray-900 dark:text-white">
              Medkit
            </h1>
            <p className="text-xl md:text-2xl text-[#D4594D] dark:text-[#EB9E94] mb-2">
              First-aid guidance in your ear, hands-free
            </p>
          </div>
          <p className="text-base md:text-lg text-gray-600 dark:text-gray-400 max-w-2xl mx-auto leading-relaxed">
            An AI first-aid coach for Meta smart glasses. Voice-guided, hands-free emergency support with real-time visual aids.
          </p>
        </div>
      </section>

      {/* YouTube embed */}
      <section className="w-full bg-white dark:bg-gray-950 px-6 pb-12 md:pb-16">
        <div className="max-w-4xl mx-auto">
          <div className="relative w-full aspect-video rounded-xl overflow-hidden border border-gray-200 dark:border-gray-800 shadow-lg">
            <iframe
              src="https://www.youtube.com/embed/-kxsSj7gAYQ?si=l909oinRqRdToN5d"
              title="Medkit video"
              allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
              allowFullScreen
              className="absolute inset-0 w-full h-full"
            />
          </div>
        </div>
      </section>
    </>
  );
}
