import { Audio } from "@remotion/media";
import { zColor } from "@remotion/zod-types";
import { AbsoluteFill, Composition, Folder, Sequence, Still, staticFile } from "remotion";
import { z } from "zod";
import { copy } from "./copy";
import { palette } from "./palette";
import { CreditScene, LaunchJourney, TrainyPoster } from "./scenes/Scenes";

export const TrainyLaunchSchema = z.object({
  brandName: z.string(),
  tagline: z.string(),
  credit: z.string(),
  accent: zColor(),
});

export type TrainyLaunchProps = z.infer<typeof TrainyLaunchSchema>;

export const TrainyLaunch: React.FC<TrainyLaunchProps> = ({
  brandName,
  tagline,
  credit,
  accent,
}) => (
  <AbsoluteFill style={{ backgroundColor: palette.canvas }}>
    <Audio
      name="Energetic Upbeat Future Bass — BombinSound"
      src={staticFile("audio/trainy-score.m4a")}
      volume={1}
    />

    <Sequence name="Trainy — one continuous journey" durationInFrames={2520} premountFor={30}>
      <LaunchJourney brandName={brandName} tagline={tagline} accent={accent} />
    </Sequence>

    <Sequence name="Created with GPT-5.6 Sol + Skills" from={2520} durationInFrames={180} premountFor={30}>
      <CreditScene credit={credit} duration={180} />
    </Sequence>
  </AbsoluteFill>
);

export const RemotionRoot: React.FC = () => (
  <Folder name="Marketing">
    <Composition
      id="TrainyLaunch"
      component={TrainyLaunch}
      durationInFrames={2700}
      fps={30}
      width={3840}
      height={2160}
      schema={TrainyLaunchSchema}
      defaultProps={{
        brandName: "Trainy",
        tagline: copy.tagline,
        credit: "Created with GPT‑5.6 Sol + Skills",
        accent: "#45C2A6",
      }}
    />
    <Still
      id="TrainyPoster"
      component={TrainyPoster}
      width={3840}
      height={2160}
      schema={z.object({ brandName: z.string(), tagline: z.string() })}
      defaultProps={{
        brandName: "Trainy",
        tagline: copy.tagline,
      }}
    />
  </Folder>
);
