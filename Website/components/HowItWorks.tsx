import { Mic, Glasses, MessageCircle, Smartphone, Camera } from 'lucide-react';

export function HowItWorks() {
  const steps = [
    {
      number: 1,
      icon: Glasses,
      title: "Connect & Start",
      description: "User wears Meta glasses and has the Medkit app open on their phone; they connect the glasses and start a session."
    },
    {
      number: 2,
      icon: Mic,
      title: "Activate the Coach",
      description: "User says \"Medkit\" (or the system auto-activates in an emergency) so the coach starts listening."
    },
    {
      number: 3,
      icon: MessageCircle,
      title: "Describe the Situation",
      description: "User describes the situation (e.g. \"Someone collapsed, not breathing\"). The AI responds with voice and may set the scenario (e.g. CPR, choking, bleeding)."
    },
    {
      number: 4,
      icon: Smartphone,
      title: "Get Step-by-Step Guidance",
      description: "The coach gives one step at a time by voice; on the phone the user sees checklists, metronome for CPR pace, and countdown timers when relevant."
    },
    {
      number: 5,
      icon: Camera,
      title: "Smart Scene Analysis (Optional)",
      description: "The glasses' camera is analyzed periodically so the coach can refine guidance (e.g. \"Move your hands a bit lower on the chest\") without the user describing every detail."
    }
  ];

  return (
    <section className="py-24 px-6 bg-gradient-to-br from-[#FDEDE8] to-white">
      <div className="max-w-6xl mx-auto">
        <h2 className="text-5xl mb-16 text-gray-900">How it works</h2>
        
        <div className="space-y-8">
          {steps.map((step) => (
            <div 
              key={step.number}
              className="bg-white/80 backdrop-blur-sm rounded-3xl p-8 md:p-10 shadow-sm hover:shadow-md transition-shadow border border-[#FAEBE8]"
            >
              <div className="flex items-start gap-6">
                <div className="flex-shrink-0">
                  <div className="w-16 h-16 rounded-2xl bg-gradient-to-br from-[#D4594D] to-[#EB9E94] flex items-center justify-center text-white shadow-lg">
                    <step.icon className="w-8 h-8" />
                  </div>
                </div>
                <div className="flex-1">
                  <div className="flex items-center gap-3 mb-3">
                    <span className="text-sm px-3 py-1 rounded-full bg-[#FAEBE8] text-[#D4594D]">
                      Step {step.number}
                    </span>
                    <h3 className="text-2xl text-gray-900">{step.title}</h3>
                  </div>
                  <p className="text-lg text-gray-700 leading-relaxed">
                    {step.description}
                  </p>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}