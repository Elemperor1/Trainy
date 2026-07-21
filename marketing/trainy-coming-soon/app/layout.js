import "./styles.css";

export const metadata = {
  metadataBase: new URL("https://trainy-coming-soon.chatgpt.site"),
  title: "Trainy — Every train journey, made clearer",
  description:
    "Trainy is an iPhone rail companion that helps you find the right service, understand what is happening, and travel with confidence. Coming soon.",
  openGraph: {
    title: "Trainy — Coming soon to iPhone",
    description: "Every train journey, made clearer.",
    images: ["/trainy-icon.png"],
  },
};

export const viewport = {
  themeColor: "#06111f",
  colorScheme: "dark",
};

/** Provides the document shell and shared metadata for the launch site. */
export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
