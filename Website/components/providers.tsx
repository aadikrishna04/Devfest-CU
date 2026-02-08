"use client";

import { ThemeProvider as NextThemesProvider } from "next-themes";
import { DarkModeToggle } from "@/components/DarkModeToggle";

export function Providers({ children }: { children: React.ReactNode }) {
  return (
    <NextThemesProvider attribute="class" defaultTheme="system" enableSystem>
      <DarkModeToggle />
      {children}
    </NextThemesProvider>
  );
}
