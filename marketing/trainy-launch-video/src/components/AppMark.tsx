import { Img, Interactive, interpolate, staticFile, useCurrentFrame, Easing } from "remotion";

type AppMarkProps = {
  readonly name?: string;
  readonly size?: number;
};

/** Renders the repository-owned Trainy app icon at a requested film size. */
export const AppMark: React.FC<AppMarkProps> = ({ name = "Trainy app mark", size = 420 }) => {
  const frame = useCurrentFrame();

  return (
    <Interactive.Div
      name={name}
      style={{
        width: size,
        height: size,
        borderRadius: size * 0.215,
        overflow: "hidden",
        boxShadow: "0 50px 150px rgba(19,116,110,0.22)",
        opacity: interpolate(frame, [0, 24], [0, 1], {
          extrapolateLeft: "clamp",
          extrapolateRight: "clamp",
        }),
        scale: interpolate(frame, [0, 42], [0.88, 1], {
          extrapolateLeft: "clamp",
          extrapolateRight: "clamp",
          easing: Easing.bezier(0.16, 1, 0.3, 1),
        }),
      }}
    >
      <Img
        name="Trainy repository app icon"
        src={staticFile("assets/trainy-app-icon.png")}
        style={{ width: "100%", height: "100%" }}
      />
    </Interactive.Div>
  );
};
