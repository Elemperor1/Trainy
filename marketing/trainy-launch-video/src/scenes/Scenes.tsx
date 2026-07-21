import {
  AbsoluteFill,
  Easing,
  Img,
  Interactive,
  Sequence,
  interpolate,
  interpolateColors,
  staticFile,
  useCurrentFrame,
} from "remotion";
import { AppMark } from "../components/AppMark";
import { PhoneFootage } from "../components/PhoneFootage";
import { copy } from "../copy";
import { fontStack, palette } from "../palette";

const cinematicEase = Easing.bezier(0.16, 1, 0.3, 1);
const symmetricEase = Easing.bezier(0.45, 0, 0.55, 1);
const captureWidth = 1206;
const captureHeight = 2622;

/** Interpolates a clamped motion value with the shared cinematic easing. */
const move = (
  frame: number,
  input: readonly number[],
  output: readonly number[],
  easing = cinematicEase,
) =>
  interpolate(frame, input, output, {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing,
  });

/** Fades a layer in and out within its local sequence window. */
const windowOpacity = (frame: number, duration: number, edge = 24) =>
  Math.min(move(frame, [0, edge], [0, 1]), move(frame, [duration - edge, duration], [1, 0]));

type CameraPoseName = "center" | "left" | "right" | "detail";

type CameraPose = {
  readonly centerX: number;
  readonly centerY: number;
  readonly scale: number;
};

const cameraPoses: Record<CameraPoseName, CameraPose> = {
  center: { centerX: 1920, centerY: 1080, scale: 0.76 },
  left: { centerX: 1050, centerY: 1080, scale: 0.72 },
  right: { centerX: 2790, centerY: 1080, scale: 0.72 },
  detail: { centerX: 1920, centerY: 1080, scale: 0.82 },
};

/** Resolves a normalized camera pose into 4K translation coordinates. */
const resolvePose = (pose: CameraPose) => ({
  x: pose.centerX - (captureWidth * pose.scale) / 2,
  y: pose.centerY - (captureHeight * pose.scale) / 2,
  scale: pose.scale,
});

/** Keeps the persistent rail and signal field mounted across the journey. */
const JourneyField: React.FC<{ readonly accent: string }> = ({ accent }) => {
  const frame = useCurrentFrame();
  const progress = frame / 2519;
  const finalRelease = move(frame, [2241, 2330], [1, 0], symmetricEase);
  const railPresence = move(frame, [0, 199, 445, 846, 2241], [1, 0.72, 0.2, 0.12, 0], symmetricEase);
  const fieldColor = interpolateColors(
    frame,
    [0, 457, 862, 1518, 1698, 2241],
    [palette.canvas, "#07100E", "#071017", "#130F09", "#07110F", palette.canvas],
  );
  const railColor = interpolateColors(
    frame,
    [0, 457, 862, 1518, 1698, 2241],
    [accent, palette.success, palette.info, palette.warning, accent, accent],
  );
  const glowX = move(frame, [0, 2519], [-320, 2920], symmetricEase);
  const dotX = 220 + progress * 3400;
  const dotY = 1450 - Math.sin(progress * Math.PI) * 590;

  return (
    <AbsoluteFill style={{ overflow: "hidden", backgroundColor: fieldColor }}>
      <div
        style={{
          position: "absolute",
          left: glowX,
          top: -280 + Math.sin(progress * Math.PI * 2) * 180,
          width: 1500,
          height: 1500,
          borderRadius: 9999,
          background: `radial-gradient(circle at center, ${railColor}1f 0%, ${railColor}0a 38%, transparent 72%)`,
          opacity: finalRelease,
        }}
      />
      <svg
        viewBox="0 0 3840 2160"
        width="3840"
        height="2160"
        aria-hidden="true"
        style={{ position: "absolute", inset: 0, opacity: finalRelease * railPresence }}
      >
        <path
          d="M-180 1600 C 620 1600, 810 1320, 1490 1320 S 2660 1280, 4020 650"
          fill="none"
          stroke={railColor}
          strokeWidth="28"
          opacity="0.07"
        />
        <path
          d="M-180 1600 C 620 1600, 810 1320, 1490 1320 S 2660 1280, 4020 650"
          fill="none"
          stroke={railColor}
          strokeWidth="4"
          strokeDasharray="5400"
          strokeDashoffset={5400 * (1 - Math.min(1, progress * 1.08))}
        />
        <path
          d="M-180 1640 C 620 1640, 810 1360, 1490 1360 S 2660 1320, 4020 690"
          fill="none"
          stroke="rgba(238,241,237,0.12)"
          strokeWidth="2"
          strokeDasharray="18 32"
          strokeDashoffset={-frame * 1.2}
        />
        <circle cx={dotX} cy={dotY} r="12" fill={railColor} />
        <circle cx={dotX} cy={dotY} r="52" fill={railColor} opacity="0.06" />
      </svg>
      <AbsoluteFill
        style={{
          background: "radial-gradient(circle at center, transparent 52%, rgba(0,0,0,0.42) 100%)",
          opacity: finalRelease,
        }}
      />
    </AbsoluteFill>
  );
};

type FilmLineProps = {
  readonly name: string;
  readonly line: string;
  readonly duration: number;
  readonly subline?: string;
  readonly x?: number;
  readonly y?: number;
  readonly width?: number;
  readonly size?: number;
  readonly align?: "left" | "center" | "right";
  readonly dark?: boolean;
};

/** Presents one short traveler-facing line with an optional factual subline. */
const FilmLine: React.FC<FilmLineProps> = ({
  name,
  line,
  duration,
  subline,
  x = 260,
  y = 560,
  width = 1180,
  size = 112,
  align = "left",
  dark = false,
}) => {
  const frame = useCurrentFrame();
  const arrival = move(frame, [0, 16], [0, 1]);
  const opacity = windowOpacity(frame, duration, 16);
  return (
    <Interactive.Div
      name={name}
      style={{
        position: "absolute",
        left: x,
        top: y,
        width,
        color: dark ? "#081512" : palette.ink,
        fontFamily: fontStack,
        textAlign: align,
        opacity,
        transform: `translate3d(0, ${interpolate(arrival, [0, 1], [34, 0])}px, 0)`,
      }}
    >
      <div
        style={{
          fontSize: size,
          lineHeight: 1.02,
          fontWeight: 620,
          letterSpacing: "-0.032em",
          textWrap: "balance",
        }}
      >
        {line}
      </div>
      {subline ? (
        <div
          style={{
            marginTop: 24,
            color: dark ? "rgba(8,21,18,0.64)" : palette.secondary,
            fontSize: 44,
            lineHeight: 1.15,
            fontWeight: 470,
            letterSpacing: "-0.012em",
          }}
        >
          {subline}
        </div>
      ) : null}
    </Interactive.Div>
  );
};

type ProductClipProps = {
  readonly name: string;
  readonly file: string;
  readonly trimBefore: number;
  readonly duration: number;
  readonly pose: CameraPoseName;
  readonly nextPose?: CameraPoseName;
  readonly moveFrom?: number;
  readonly moveTo?: number;
  readonly playbackRate?: number;
  readonly accent?: string;
};

/** Places a simulator capture in the shared crop-safe film camera. */
const ProductClip: React.FC<ProductClipProps> = ({
  name,
  file,
  trimBefore,
  duration,
  pose,
  nextPose = pose,
  moveFrom = 0,
  moveTo = duration,
  playbackRate = 1,
  accent = palette.accentBright,
}) => {
  const frame = useCurrentFrame();
  const start = resolvePose(cameraPoses[pose]);
  const end = resolvePose(cameraPoses[nextPose]);
  const position = move(frame, [moveFrom, moveTo], [0, 1]);
  const x = interpolate(position, [0, 1], [start.x, end.x]);
  const y = interpolate(position, [0, 1], [start.y, end.y]);
  const scale = interpolate(position, [0, 1], [start.scale, end.scale]);
  const opacity = windowOpacity(frame, duration, 8);
  const displayedWidth = captureWidth * scale;
  const displayedHeight = captureHeight * scale;

  return (
    <>
      <div
        style={{
          position: "absolute",
          left: x - 280,
          top: y - 80,
          width: displayedWidth + 560,
          height: displayedHeight + 160,
          borderRadius: 9999,
          background: `radial-gradient(ellipse at center, ${accent}24 0%, ${accent}0d 42%, transparent 72%)`,
          opacity,
        }}
      />
      <Interactive.Div
        name={`${name} camera`}
        style={{
          position: "absolute",
          left: 0,
          top: 0,
          opacity,
          transformOrigin: "0 0",
          transform: `translate3d(${x}px, ${y}px, 0) scale(${scale})`,
          willChange: "transform, opacity",
        }}
      >
        <PhoneFootage
          name={name}
          file={file}
          trimBefore={trimBefore}
          playbackRate={playbackRate}
          width={captureWidth}
          height={captureHeight}
          accent={accent}
          animateIn={false}
        />
      </Interactive.Div>
    </>
  );
};

/** Introduces the Trainy mark and opening traveler question. */
const OpeningBeat: React.FC<{ readonly duration: number }> = ({ duration }) => {
  const frame = useCurrentFrame();
  const fade = move(frame, [duration - 28, duration], [1, 0]);
  return (
    <AbsoluteFill style={{ opacity: fade }}>
      <Sequence name="Opening Trainy mark" from={52} durationInFrames={147} layout="none">
        <div style={{ position: "absolute", left: 1830, top: 550 }}>
          <AppMark name="Opening Trainy mark" size={180} />
        </div>
      </Sequence>
      <Sequence name="Going somewhere?" from={84} durationInFrames={108} layout="none">
        <FilmLine
          name="Opening question"
          line={copy.hook}
          duration={108}
          x={820}
          y={1030}
          width={2200}
          size={126}
          align="center"
        />
      </Sequence>
    </AbsoluteFill>
  );
};

/** Resolves the product journey into Trainy's final brand identity. */
const EndIdentity: React.FC<{
  readonly brandName: string;
  readonly tagline: string;
  readonly duration: number;
}> = ({ brandName, tagline, duration }) => {
  const frame = useCurrentFrame();
  const wash = move(frame, [0, 36], [0, 1], symmetricEase);
  const arrival = move(frame, [16, 48], [0, 1]);
  const hold = move(frame, [duration - 28, duration], [1, 0], symmetricEase);
  return (
    <AbsoluteFill
      style={{
        alignItems: "center",
        justifyContent: "center",
        backgroundColor: `rgba(225,240,234,${wash})`,
        fontFamily: fontStack,
        opacity: hold,
      }}
    >
      <Interactive.Div
        name="Final Trainy identity"
        style={{
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          color: "#081512",
          opacity: arrival,
          transform: `translate3d(0, ${interpolate(arrival, [0, 1], [42, 0])}px, 0)`,
        }}
      >
        <Img
          name="Trainy repository app icon"
          src={staticFile("assets/trainy-app-icon.png")}
          style={{
            width: 240,
            height: 240,
            borderRadius: 54,
            boxShadow: "0 44px 110px rgba(6,31,26,0.16)",
          }}
        />
        <div
          style={{
            marginTop: 48,
            fontSize: 132,
            lineHeight: 1,
            fontWeight: 650,
            letterSpacing: "-0.035em",
          }}
        >
          {brandName}
        </div>
        <div
          style={{
            marginTop: 30,
            fontSize: 68,
            lineHeight: 1.08,
            fontWeight: 470,
            letterSpacing: "-0.022em",
          }}
        >
          {tagline}
        </div>
      </Interactive.Div>
    </AbsoluteFill>
  );
};

/** Runs the continuous rider journey through all product and identity beats. */
export const LaunchJourney: React.FC<{
  readonly brandName: string;
  readonly tagline: string;
  readonly accent: string;
}> = ({ brandName, tagline, accent }) => (
  <AbsoluteFill style={{ overflow: "hidden", backgroundColor: palette.canvas }}>
    <JourneyField accent={accent} />

    <Sequence name="Opening question" durationInFrames={199} layout="none">
      <OpeningBeat duration={199} />
    </Sequence>

    <Sequence
      name="Welcome becomes the first tracked trip in one take"
      from={183}
      durationInFrames={270}
      layout="none"
    >
      <ProductClip
        name="Welcome becomes the first tracked trip in one take"
        file="onboarding.mp4"
        trimBefore={360}
        duration={270}
        playbackRate={1}
        pose="right"
        nextPose="center"
        moveFrom={198}
        moveTo={246}
      />
    </Sequence>
    <Sequence name="Meet your train" from={245} durationInFrames={180} layout="none">
      <FilmLine name="Meet your train" line={copy.welcome} duration={180} x={260} y={760} width={1220} />
    </Sequence>

    <Sequence
      name="Tokyo to Shin-Osaka continuous search journey"
      from={445}
      durationInFrames={596}
      layout="none"
    >
      <ProductClip
        name="Tokyo to Shin-Osaka continuous search journey"
        file="shinkansen-search.mp4"
        trimBefore={240}
        duration={600}
        playbackRate={1}
        pose="center"
        accent={palette.success}
      />
    </Sequence>
    <Sequence name="Tokyo to Shin-Osaka" from={480} durationInFrames={150} layout="none">
      <FilmLine
        name="Tokyo to Shin-Osaka"
        line={copy.japan.route}
        duration={150}
        x={250}
        y={370}
        width={1060}
        size={104}
      />
    </Sequence>
    <Sequence name="Nozomi 231 at 09:21" from={630} durationInFrames={150} layout="none">
      <FilmLine
        name="Nozomi 231 at 09:21"
        line={copy.japan.trip}
        duration={150}
        x={250}
        y={1380}
        width={1040}
        size={82}
      />
    </Sequence>

    <Sequence
      name="Utrecht continuous station-to-departures journey"
      from={1033}
      durationInFrames={645}
      layout="none"
    >
      <ProductClip
        name="Utrecht continuous station-to-departures journey"
        file="utrecht-departures.mp4"
        trimBefore={300}
        duration={645}
        playbackRate={1}
        pose="center"
        nextPose="right"
        moveFrom={120}
        moveTo={180}
        accent={palette.info}
      />
    </Sequence>
    <Sequence name="Utrecht Centraal" from={1130} durationInFrames={140} layout="none">
      <FilmLine
        name="Utrecht Centraal"
        line={copy.netherlands.station}
        duration={140}
        x={250}
        y={390}
        width={1100}
        size={102}
      />
    </Sequence>
    <Sequence name="What leaves next?" from={1320} durationInFrames={150} layout="none">
      <FilmLine
        name="What leaves next"
        line={copy.netherlands.question}
        duration={150}
        x={250}
        y={790}
        width={1280}
        size={114}
      />
    </Sequence>
    <Sequence name="Live when it is live" from={1535} durationInFrames={125} layout="none">
      <FilmLine
        name="Live when it is live"
        line={copy.availability.live}
        duration={125}
        x={250}
        y={470}
        width={1320}
        size={104}
      />
    </Sequence>

    <Sequence
      name="Unavailable state recovers through visible retry in one take"
      from={1670}
      durationInFrames={120}
      layout="none"
    >
      <ProductClip
        name="Unavailable state recovers through visible retry in one take"
        file="failure-recovery.mp4"
        trimBefore={480}
        duration={120}
        playbackRate={1}
        pose="center"
        accent={palette.warning}
      />
    </Sequence>
    <Sequence name="Clear when it is not live" from={1690} durationInFrames={90} layout="none">
      <FilmLine
        name="Clear when it is not live"
        line={copy.availability.unavailable}
        duration={90}
        x={250}
        y={1410}
        width={1100}
        size={104}
      />
    </Sequence>

    <Sequence
      name="Dark Mode and AX2XL Dynamic Type"
      from={1782}
      durationInFrames={60}
      layout="none"
    >
      <ProductClip
        name="Dark Mode and AX2XL Dynamic Type"
        file="accessibility.mp4"
        trimBefore={960}
        duration={60}
        playbackRate={1}
        pose="center"
        accent={palette.accentBright}
      />
    </Sequence>

    <Sequence
      name="Default-off diagnostics choice"
      from={1834}
      durationInFrames={113}
      layout="none"
    >
      <ProductClip
        name="Default-off diagnostics choice"
        file="privacy.mp4"
        trimBefore={270}
        duration={113}
        playbackRate={1}
        pose="center"
        accent={palette.accentBright}
      />
    </Sequence>
    <Sequence name="OpenAI Build Week contribution" from={1845} durationInFrames={90} layout="none">
      <FilmLine
        name="Built with Codex and GPT-5.6"
        line={copy.build.line}
        duration={90}
        x={250}
        y={650}
        width={1080}
        size={96}
      />
    </Sequence>

    <Sequence
      name="Final matching Nozomi result resolves to the tracked trip"
      from={1939}
      durationInFrames={150}
      layout="none"
    >
      <ProductClip
        name="Final matching Nozomi result resolves to the tracked trip"
        file="shinkansen-search.mp4"
        trimBefore={690}
        duration={150}
        playbackRate={1}
        pose="center"
        accent={palette.success}
      />
    </Sequence>

    <Sequence name="Trainy identity — Know before you go" from={2081} durationInFrames={439} layout="none">
      <EndIdentity brandName={brandName} tagline={tagline} duration={439} />
    </Sequence>
  </AbsoluteFill>
);

/** Holds the required creation credit over the score's silent tail. */
export const CreditScene: React.FC<{ readonly credit: string; readonly duration: number }> = ({
  credit,
  duration,
}) => {
  const frame = useCurrentFrame();
  return (
    <AbsoluteFill
      style={{
        alignItems: "center",
        justifyContent: "center",
        backgroundColor: "#000000",
        fontFamily: fontStack,
      }}
    >
      <Interactive.Div
        name="Final GPT-5.6 credit"
        style={{
          color: "#FFFFFF",
          fontSize: 58,
          lineHeight: 1.2,
          fontWeight: 510,
          letterSpacing: "-0.018em",
          textAlign: "center",
          opacity: interpolate(frame, [0, 18, duration - 48, duration - 14], [0, 1, 1, 0], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
            easing: symmetricEase,
          }),
        }}
      >
        {credit}
      </Interactive.Div>
    </AbsoluteFill>
  );
};

/** Renders the static launch poster from the same identity system. */
export const TrainyPoster: React.FC<{
  readonly brandName: string;
  readonly tagline: string;
}> = ({ brandName, tagline }) => (
  <AbsoluteFill
    style={{
      alignItems: "center",
      justifyContent: "center",
      background: "radial-gradient(circle at 50% 44%, #173A34 0%, #09120F 48%, #050706 100%)",
      color: palette.ink,
      fontFamily: fontStack,
    }}
  >
    <div
      style={{
        display: "flex",
        alignItems: "center",
        gap: 150,
      }}
    >
      <Img
        src={staticFile("assets/trainy-app-icon.png")}
        style={{
          width: 650,
          height: 650,
          borderRadius: 142,
          boxShadow: "0 80px 220px rgba(69,194,166,0.19)",
        }}
      />
      <div style={{ display: "flex", flexDirection: "column", maxWidth: 1500 }}>
        <div style={{ fontSize: 188, lineHeight: 1, fontWeight: 650, letterSpacing: "-0.035em" }}>
          {brandName}
        </div>
        <div
          style={{
            marginTop: 42,
            color: palette.secondary,
            fontSize: 70,
            lineHeight: 1.08,
            fontWeight: 470,
            letterSpacing: "-0.022em",
          }}
        >
          {tagline}
        </div>
      </div>
    </div>
  </AbsoluteFill>
);
