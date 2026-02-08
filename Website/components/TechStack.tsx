import { Smartphone, Server, Brain } from 'lucide-react';

export function TechStack() {
  const stacks = [
    {
      icon: Smartphone,
      title: "Glasses & Mobile",
      items: [
        "Meta smart glasses",
        "Meta DAT SDK (MWDATCamera, MWDATCore)",
        "iOS (Swift, SwiftUI)",
        "AVFoundation",
        "Speech (wake word)",
        "Checklists, metronome & timers UI"
      ]
    },
    {
      icon: Server,
      title: "Backend",
      items: [
        "Modal",
        "Python",
        "FastAPI",
        "WebSockets",
        "OpenAI Python SDK",
        "websockets library"
      ]
    },
    {
      icon: Brain,
      title: "AI",
      items: [
        "OpenAI Realtime API (voice + tools)",
        "GPT-4o (vision for scene descriptions)",
        "Whisper (user transcription in Realtime)"
      ]
    }
  ];

  return (
    <section className="py-24 px-6 bg-white">
      <div className="max-w-6xl mx-auto">
        <h2 className="text-5xl mb-6 text-gray-900">Tech stack</h2>
        <p className="text-xl text-gray-600 mb-16">
          Technologies powering Medkit
        </p>
        
        <div className="grid md:grid-cols-3 gap-8">
          {stacks.map((stack, index) => (
            <div 
              key={index}
              className="bg-gradient-to-br from-[#FDEDE8] to-white rounded-3xl p-8 shadow-sm hover:shadow-md transition-shadow border border-[#FAEBE8]"
            >
              <div className="w-16 h-16 rounded-2xl bg-gradient-to-br from-[#D4594D] to-[#EB9E94] flex items-center justify-center mb-6 shadow-md">
                <stack.icon className="w-8 h-8 text-white" />
              </div>
              <h3 className="text-2xl mb-6 text-gray-900">{stack.title}</h3>
              <ul className="space-y-3">
                {stack.items.map((item, itemIndex) => (
                  <li key={itemIndex} className="text-gray-700 leading-relaxed flex items-start">
                    <span className="text-[#D4594D] mr-2">•</span>
                    <span>{item}</span>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
