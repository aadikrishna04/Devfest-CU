import { Glasses, Smartphone, Server, Brain, ArrowRight, ArrowLeftRight } from 'lucide-react';

export function Architecture() {
  return (
    <section className="py-16 px-6 bg-white dark:bg-gray-950">
      <div className="max-w-6xl mx-auto">
        <h2 className="text-4xl mb-4 text-gray-900 dark:text-white">Architecture</h2>
        <p className="text-base text-gray-600 dark:text-gray-400 mb-12">
          System flow from glasses to AI
        </p>
        
        {/* Architecture diagram */}
        <div className="bg-gray-50 dark:bg-gray-900 rounded-2xl p-6 md:p-10 border border-gray-200 dark:border-gray-800 mb-10">
          <div className="flex flex-col md:flex-row items-center justify-between gap-8">
            {/* Glasses */}
            <div className="flex-1 text-center">
              <div className="w-16 h-16 mx-auto rounded-xl bg-[#D4594D]/10 dark:bg-[#D4594D]/20 flex items-center justify-center mb-3">
                <Glasses className="w-8 h-8 text-[#D4594D]" />
              </div>
              <h3 className="text-base mb-1 text-gray-900 dark:text-white">Meta Smart Glasses</h3>
              <p className="text-sm text-gray-600 dark:text-gray-400">Camera + Mic</p>
            </div>

            <ArrowRight className="w-6 h-6 text-[#D4594D] hidden md:block" />
            <div className="md:hidden w-full h-px bg-[#D4594D]" />

            {/* Phone */}
            <div className="flex-1 text-center">
              <div className="w-16 h-16 mx-auto rounded-xl bg-[#D4594D]/10 dark:bg-[#D4594D]/20 flex items-center justify-center mb-3">
                <Smartphone className="w-8 h-8 text-[#D4594D]" />
              </div>
              <h3 className="text-base mb-1 text-gray-900 dark:text-white">Phone (Medkit App)</h3>
              <p className="text-sm text-gray-600 dark:text-gray-400">Meta SDK, Wake Word,<br />Tools, Wireframe</p>
            </div>

            <ArrowLeftRight className="w-6 h-6 text-[#D4594D] hidden md:block" />
            <div className="md:hidden w-full h-px bg-[#D4594D]" />

            {/* Backend */}
            <div className="flex-1 text-center">
              <div className="w-16 h-16 mx-auto rounded-xl bg-[#D4594D]/10 dark:bg-[#D4594D]/20 flex items-center justify-center mb-3">
                <Server className="w-8 h-8 text-[#D4594D]" />
              </div>
              <h3 className="text-base mb-1 text-gray-900 dark:text-white">Backend</h3>
              <p className="text-sm text-gray-600 dark:text-gray-400">WebSocket Bridge,<br />Scene Analysis</p>
            </div>

            <ArrowLeftRight className="w-6 h-6 text-[#D4594D] hidden md:block" />
            <div className="md:hidden w-full h-px bg-[#D4594D]" />

            {/* OpenAI */}
            <div className="flex-1 text-center">
              <div className="w-16 h-16 mx-auto rounded-xl bg-[#D4594D]/10 dark:bg-[#D4594D]/20 flex items-center justify-center mb-3">
                <Brain className="w-8 h-8 text-[#D4594D]" />
              </div>
              <h3 className="text-base mb-1 text-gray-900 dark:text-white">OpenAI</h3>
              <p className="text-sm text-gray-600 dark:text-gray-400">Realtime API + GPT-4o</p>
            </div>
          </div>
        </div>

        {/* Tech Stack */}
        <div className="grid md:grid-cols-3 gap-6">
          <div className="bg-gray-50 dark:bg-gray-900 rounded-xl p-6 border border-gray-200 dark:border-gray-800">
            <h3 className="text-base mb-4 text-[#D4594D]">Glasses & Mobile</h3>
            <ul className="space-y-1 text-sm text-gray-600 dark:text-gray-400">
              <li>• Meta DAT SDK</li>
              <li>• iOS (Swift, SwiftUI)</li>
              <li>• AVFoundation, Speech</li>
              <li>• SceneKit (wireframe)</li>
            </ul>
          </div>

          <div className="bg-gray-50 dark:bg-gray-900 rounded-xl p-6 border border-gray-200 dark:border-gray-800">
            <h3 className="text-base mb-4 text-[#D4594D]">Backend</h3>
            <ul className="space-y-1 text-sm text-gray-600 dark:text-gray-400">
              <li>• Modal (Python)</li>
              <li>• FastAPI</li>
              <li>• WebSockets</li>
              <li>• OpenAI Python SDK</li>
            </ul>
          </div>

          <div className="bg-gray-50 dark:bg-gray-900 rounded-xl p-6 border border-gray-200 dark:border-gray-800">
            <h3 className="text-base mb-4 text-[#D4594D]">AI</h3>
            <ul className="space-y-1 text-sm text-gray-600 dark:text-gray-400">
              <li>• OpenAI Realtime API</li>
              <li>• GPT-4o (vision)</li>
              <li>• Whisper transcription</li>
            </ul>
          </div>
        </div>
      </div>
    </section>
  );
}