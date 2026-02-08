export function WhatIsMedkit() {
  return (
    <section className="py-24 px-6 bg-white">
      <div className="max-w-5xl mx-auto">
        <h2 className="text-5xl mb-16 text-gray-900">What is Medkit?</h2>
        
        <div className="space-y-12">
          {/* Problem */}
          <div className="bg-gradient-to-br from-[#FDEDE8] to-[#FAEBE8] rounded-3xl p-8 md:p-12">
            <h3 className="text-2xl mb-4 text-[#D4594D]">The Problem</h3>
            <p className="text-lg text-gray-700 leading-relaxed">
              In a first-aid situation, people are stressed, hands are busy, and they can't read long instructions or watch videos. Traditional first-aid resources fail when you need them most.
            </p>
          </div>

          {/* Solution */}
          <div className="bg-gradient-to-br from-[#FAEBE8] to-white rounded-3xl p-8 md:p-12 border border-[#EB9E94]/20">
            <h3 className="text-2xl mb-4 text-[#D4594D]">The Solution</h3>
            <p className="text-lg text-gray-700 leading-relaxed">
              Medkit uses the glasses' mic and camera plus an AI coach so the user gets spoken, short instructions in real time and glanceable support on the phone (transcript, timers, checklists, body-position guide). No touching screens, no searching through videos — just clear, immediate guidance.
            </p>
          </div>

          {/* Product definition */}
          <div className="border-l-4 border-[#D4594D] pl-8 py-4">
            <p className="text-xl text-gray-800 leading-relaxed italic">
              "Medkit is a first-aid coaching experience for Meta smart glasses: say what's happening, get voice guidance and on-screen aids (CPR rhythm, timers, checklists, body-position visuals) without touching a screen."
            </p>
          </div>
        </div>
      </div>
    </section>
  );
}