import Foundation

enum ShinkansenRouteCatalog {
    static let routes: [LiveTrainRoute] = [
        LiveTrainRoute(
            id: "tokaido",
            name: "Tokaido Shinkansen",
            summary: "JR Central trunk route between Tokyo, Nagoya, Kyoto, and Shin-Osaka.",
            destinations: ["Tokyo", "Shin-Yokohama", "Nagoya", "Kyoto", "Shin-Osaka", "Nozomi", "Hikari", "Kodama"]
        ),
        LiveTrainRoute(
            id: "sanyo-kyushu",
            name: "Sanyo and Kyushu Shinkansen",
            summary: "JR West and JR Kyushu high-speed route from Shin-Osaka through Hakata to Kagoshima-Chuo.",
            destinations: ["Shin-Osaka", "Okayama", "Hiroshima", "Hakata", "Kumamoto", "Kagoshima-Chuo", "Sakura", "Mizuho"]
        ),
        LiveTrainRoute(
            id: "tohoku",
            name: "Tohoku Shinkansen",
            summary: "JR East route from Tokyo through Sendai and Morioka to Shin-Aomori.",
            destinations: ["Tokyo", "Omiya", "Sendai", "Morioka", "Shin-Aomori", "Hayabusa", "Yamabiko"]
        ),
        LiveTrainRoute(
            id: "hokuriku",
            name: "Hokuriku Shinkansen",
            summary: "JR East and JR West route from Tokyo to Nagano, Toyama, Kanazawa, and Tsuruga.",
            destinations: ["Tokyo", "Nagano", "Toyama", "Kanazawa", "Tsuruga", "Kagayaki", "Hakutaka"]
        ),
        LiveTrainRoute(
            id: "joetsu",
            name: "Joetsu Shinkansen",
            summary: "JR East route from Tokyo to Takasaki, Echigo-Yuzawa, and Niigata.",
            destinations: ["Tokyo", "Takasaki", "Echigo-Yuzawa", "Niigata", "Toki", "Tanigawa"]
        ),
        LiveTrainRoute(
            id: "hokkaido",
            name: "Tohoku and Hokkaido Shinkansen",
            summary: "Through service from Tokyo and Tohoku to Shin-Hakodate-Hokuto.",
            destinations: ["Tokyo", "Sendai", "Morioka", "Shin-Aomori", "Shin-Hakodate-Hokuto", "Hayabusa"]
        ),
        LiveTrainRoute(
            id: "akita",
            name: "Akita Shinkansen",
            summary: "JR East mini-shinkansen route from Tokyo and Morioka to Akita.",
            destinations: ["Tokyo", "Sendai", "Morioka", "Tazawako", "Akita", "Komachi"]
        ),
        LiveTrainRoute(
            id: "yamagata",
            name: "Yamagata Shinkansen",
            summary: "JR East mini-shinkansen route from Tokyo and Fukushima to Yamagata and Shinjo.",
            destinations: ["Tokyo", "Fukushima", "Yamagata", "Shinjo", "Tsubasa"]
        )
    ]

    static let routeRank: [String: Int] = Dictionary(uniqueKeysWithValues: routes.enumerated().map { ($0.element.id, $0.offset) })

    static let odptRailwaysByRouteID: [String: [ODPTRailwayReference]] = [
        "tokaido": [
            ODPTRailwayReference(railwayID: "odpt.Railway:JR-Central.TokaidoShinkansen", operatorID: "odpt.Operator:JR-Central")
        ],
        "sanyo-kyushu": [
            ODPTRailwayReference(railwayID: "odpt.Railway:JR-West.SanyoShinkansen", operatorID: "odpt.Operator:JR-West"),
            ODPTRailwayReference(railwayID: "odpt.Railway:JR-Kyushu.KyushuShinkansen", operatorID: "odpt.Operator:JR-Kyushu")
        ],
        "tohoku": [
            ODPTRailwayReference(railwayID: "odpt.Railway:JR-East.TohokuShinkansen", operatorID: "odpt.Operator:JR-East")
        ],
        "hokuriku": [
            ODPTRailwayReference(railwayID: "odpt.Railway:JR-East.HokurikuShinkansen", operatorID: "odpt.Operator:JR-East"),
            ODPTRailwayReference(railwayID: "odpt.Railway:JR-West.HokurikuShinkansen", operatorID: "odpt.Operator:JR-West")
        ],
        "joetsu": [
            ODPTRailwayReference(railwayID: "odpt.Railway:JR-East.JoetsuShinkansen", operatorID: "odpt.Operator:JR-East")
        ],
        "hokkaido": [
            ODPTRailwayReference(railwayID: "odpt.Railway:JR-East.TohokuShinkansen", operatorID: "odpt.Operator:JR-East"),
            ODPTRailwayReference(railwayID: "odpt.Railway:JR-Hokkaido.HokkaidoShinkansen", operatorID: "odpt.Operator:JR-Hokkaido")
        ],
        "akita": [
            ODPTRailwayReference(railwayID: "odpt.Railway:JR-East.AkitaShinkansen", operatorID: "odpt.Operator:JR-East")
        ],
        "yamagata": [
            ODPTRailwayReference(railwayID: "odpt.Railway:JR-East.YamagataShinkansen", operatorID: "odpt.Operator:JR-East")
        ]
    ]
}

extension ShinkansenTrainProvider {
    static var routes: [LiveTrainRoute] { ShinkansenRouteCatalog.routes }
    static var routeRank: [String: Int] { ShinkansenRouteCatalog.routeRank }
    static var odptRailwaysByRouteID: [String: [ODPTRailwayReference]] { ShinkansenRouteCatalog.odptRailwaysByRouteID }
}
