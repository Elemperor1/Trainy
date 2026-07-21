import { Video } from "@remotion/media";
import { Easing, Interactive, interpolate, staticFile, useCurrentFrame } from "remotion";
import { palette } from "../palette";

type PhoneFootageProps = {
  readonly name: string;
  readonly file: string;
  readonly width?: number;
  readonly height?: number;
  readonly trimBefore?: number;
  readonly secondaryTrimBefore?: number;
  readonly crossfadeAt?: number;
  readonly playbackRate?: number;
  readonly enterFrom?: "left" | "right" | "bottom";
  readonly accent?: string;
  readonly animateIn?: boolean;
};

export const PhoneFootage: React.FC<PhoneFootageProps> = ({
  name,
  file,
  width = 1206,
  height = 2622,
  trimBefore = 0,
  secondaryTrimBefore,
  crossfadeAt = 150,
  playbackRate = 1,
  enterFrom = "right",
  accent = palette.accentBright,
  animateIn = true,
}) => {
  const frame = useCurrentFrame();
  const translateFrom =
    enterFrom === "left" ? "-120px 0px" : enterFrom === "bottom" ? "0px 120px" : "120px 0px";

  return (
    <Interactive.Div
      name={`${name} mask`}
      style={{
        width,
        height,
        position: "relative",
        overflow: "hidden",
        borderRadius: 124,
        backgroundColor: "#050607",
        outline: "2px solid rgba(238,241,237,0.15)",
        boxShadow: "0 0 0 8px rgba(4,7,8,0.72), 0 0 0 10px rgba(238,241,237,0.055)",
        opacity: animateIn
          ? interpolate(frame, [0, 24], [0, 1], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
              easing: Easing.bezier(0.16, 1, 0.3, 1),
            })
          : 1,
        translate: animateIn
          ? interpolate(frame, [0, 36], [translateFrom, "0px 0px"], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
              easing: Easing.bezier(0.16, 1, 0.3, 1),
            })
          : "0px 0px",
        scale: animateIn
          ? interpolate(frame, [0, 44], [0.965, 1], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
              easing: Easing.bezier(0.16, 1, 0.3, 1),
            })
          : 1,
      }}
    >
      <Video
        name={secondaryTrimBefore === undefined ? name : `${name} light appearance`}
        src={staticFile(`footage/${file}`)}
        trimBefore={trimBefore}
        playbackRate={playbackRate}
        muted
        objectFit="cover"
        style={{
          position: "absolute",
          inset: 8,
          width: "calc(100% - 16px)",
          height: "calc(100% - 16px)",
          borderRadius: 112,
          opacity:
            secondaryTrimBefore === undefined
              ? 1
              : interpolate(frame, [crossfadeAt - 12, crossfadeAt + 12], [1, 0], {
                  extrapolateLeft: "clamp",
                  extrapolateRight: "clamp",
                }),
        }}
      />
      {secondaryTrimBefore === undefined ? null : (
        <Video
          name={`${name} dark appearance`}
          src={staticFile(`footage/${file}`)}
          trimBefore={secondaryTrimBefore}
          playbackRate={playbackRate}
          muted
          objectFit="cover"
          style={{
            position: "absolute",
            inset: 8,
            width: "calc(100% - 16px)",
            height: "calc(100% - 16px)",
            borderRadius: 112,
            opacity: interpolate(frame, [crossfadeAt - 12, crossfadeAt + 12], [0, 1], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
            }),
          }}
        />
      )}
      <div
        style={{
          position: "absolute",
          inset: 0,
          borderRadius: 124,
          background: "linear-gradient(135deg, rgba(255,255,255,0.12) 0%, rgba(255,255,255,0.025) 14%, transparent 31%, transparent 72%, rgba(255,255,255,0.035) 100%)",
          boxShadow: `inset 0 0 0 2px ${accent}24, inset 0 0 0 10px rgba(0,0,0,0.3)`,
          pointerEvents: "none",
        }}
      />
    </Interactive.Div>
  );
};
