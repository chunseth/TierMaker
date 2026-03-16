import Foundation

/// Template definition; mirrors app TierTemplate for script use.
struct Template {
    let name: String
    let category: String
    let items: [TemplateItem]

    struct TemplateItem {
        let name: String
        let imageURL: URL
    }
}

extension Template {
    /// Same templates as TierTemplate.all in the app (for URL decode and --random).
    static let all: [Template] = [
        Template(
            name: "Ranked Anime",
            category: "Anime",
            items: [
                TemplateItem(name: "Attack on Titan", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1771637997/TierList_AttackOnTitan_ecgkuf.jpg")!),
                TemplateItem(name: "Death Note", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1771637997/TierList_DeathNote_rjwm6i.jpg")!),
                TemplateItem(name: "Demon Slayer", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1771637997/TierList_DemonSlayer_trduv3.jpg")!),
                TemplateItem(name: "My Hero Academia", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1771637997/TierList_MyHeroAcademia_tavmas.jpg")!),
                TemplateItem(name: "Jujutsu Kaisen", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1771637997/TierList_JujutsuKaisen_v4tewf.jpg")!),
                TemplateItem(name: "Bleach", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1771637999/TierList_Bleach_yn8ou7.png")!),
                TemplateItem(name: "Naruto", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1771637998/TierList_Naruto_d1pvz0.jpg")!),
                TemplateItem(name: "One Piece", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1771637999/TierList_OnePiece_jkpgjv.jpg")!),
                TemplateItem(name: "Steins;Gate", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1771637999/TierList_SteinsGate_qzftt8.jpg")!),
                TemplateItem(name: "Neon Genesis Evangelion", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1771638000/TierList_NeonGenesisEvangelion_jkfy6q.jpg")!)
            ]
        ),
        Template(
            name: "Movies",
            category: "Movies",
            items: [
                TemplateItem(name: "A Bug's Life", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1736206704/zd0rc86nhgsrq9cbig7o.jpg")!),
                TemplateItem(name: "Cars 2", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1736206706/nmrcdqx2duqbpcl29xml.webp")!),
                TemplateItem(name: "Brave", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1736206706/qrxylyliemcprmig74e5.jpg")!),
                TemplateItem(name: "Cars", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1736206707/lueb0qcn5ouzgkjs6mv1.png")!),
                TemplateItem(name: "Coco", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1736206709/tbh3rbfflng76gmbxzrr.jpg")!),
                TemplateItem(name: "Cars 3", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1736206709/azwbkg1dyucvjvvq17o9.jpg")!),
                TemplateItem(name: "Elemental", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1736206710/aiyqtpztidedufawde66.jpg")!),
                TemplateItem(name: "Finding Dory", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1736206711/dchqslbp3mir1p95woev.jpg")!),
                TemplateItem(name: "Finding Nemo", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1736206712/lgyn03obstibfdttty2f.jpg")!),
                TemplateItem(name: "The Incredibles", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1736206713/bzw0r4ff4qtzxffxzzh6.jpg")!),
                TemplateItem(name: "The Incredibles 2", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1736206714/yaaw5k2ivckoza8t0rio.jpg")!),
                TemplateItem(name: "Inside Out 2", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1736206715/ttxli3uccex4qa00d3lk.jpg")!),
                TemplateItem(name: "Inside Out", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1736206715/h6wib2tu3uwnx45dm0my.jpg")!),
                TemplateItem(name: "Lightyear", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1736206716/h37ap2mj4l6u1sugi1wf.jpg")!),
                TemplateItem(name: "Luca", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1736206717/ftqocvky8qu4lfxcsyww.jpg")!),
                TemplateItem(name: "Monsters Inc", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1736206718/v3ytborshfgp8mjbynvl.jpg")!),
                TemplateItem(name: "Monsters University", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1736206782/wadyp70jejeiwczex8tg.jpg")!),
                TemplateItem(name: "Onward", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1736206783/z0fmmjmqyvqokmee9lwm.jpg")!),
                TemplateItem(name: "Ratatouille", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1736206784/tkhqvdduf7hqxdezxxqd.jpg")!),
                TemplateItem(name: "Soul", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1736206785/srquhswbac2iu5b1npcl.jpg")!),
                TemplateItem(name: "Toy Story", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1736206786/on4hdfs1hwmf37lnccmn.jpg")!),
                TemplateItem(name: "The Good Dinosaur", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1736206786/pmnbz9wlvkdxhaayaiio.jpg")!),
                TemplateItem(name: "Toy Story 2", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1736206787/ojwtujskhdikt8d6boyr.png")!),
                TemplateItem(name: "Toy Story 3", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1736206788/kcmwppzmsb3tblt3wblr.jpg")!),
                TemplateItem(name: "Toy Story 4", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1736206789/w9cehdyt1gayncyeb61q.jpg")!),
                TemplateItem(name: "Turning Red", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1736206784/tkhqvdduf7hqxdezxxqd.jpg")!),
                TemplateItem(name: "Up", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1736206791/l0be3lkmm0ldtm4jsuo5.jpg")!),
                TemplateItem(name: "Wall E", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1736206792/tqwyyafevfck5go4ysrj.jpg")!)
            ]
        ),
        Template(
            name: "Video Games",
            category: "Gaming",
            items: [
                TemplateItem(name: "Breath of the Wild", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1771638849/TierList_BreathOfTheWild_efl0e8.jpg")!),
                TemplateItem(name: "Elden Ring", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1771638848/TierList_EldenRing_komvmo.jpg")!),
                TemplateItem(name: "Red Dead Redemption 2", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1771638848/TierList_RDR2_kyiyjd.jpg")!),
                TemplateItem(name: "The Witcher 3", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1771638848/TierList_TheWitcher3_vawbyr.jpg")!),
                TemplateItem(name: "Cyberpunk 2077", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1771638848/TierList_Cyberpunk2077_labzqj.jpg")!),
                TemplateItem(name: "Final Fantasy VII", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1771638848/TierList_FF7_i5hvaf.jpg")!),
                TemplateItem(name: "Halo Infinite", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1771638849/TierList_HaloInfinite_xbigua.png")!),
                TemplateItem(name: "God of War", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1771638848/TierList_GodOfWar_arcagq.jpg")!),
                TemplateItem(name: "Metroid Prime", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1771638847/TierList_MetroidPrime_kbdiih.jpg")!)
            ]
        ),
        Template(
            name: "Fast Food",
            category: "Food",
            items: [
                TemplateItem(name: "McDonald's", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1771639417/TierList_McD_jst4cs.png")!),
                TemplateItem(name: "Burger King", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1771639417/TierList_BK_lbon0s.png")!),
                TemplateItem(name: "Wendy's", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1771639417/TierList_Wendys_sjb9bz.png")!),
                TemplateItem(name: "Chick-fil-A", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1771639417/TierList_CFA_gdwbsl.png")!),
                TemplateItem(name: "Taco Bell", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1771639417/TierList_TB_kivwyi.png")!),
                TemplateItem(name: "KFC", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1771639270/TierList_KFC_xgw35q.png")!),
                TemplateItem(name: "Subway", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1771639269/TierList_Subway_uajdcq.jpg")!),
                TemplateItem(name: "Chipotle", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1771639270/TierList_Chipotle_iuifpn.png")!),
                TemplateItem(name: "Popeyes", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1771639270/TierList_Popeyes_ney667.jpg")!),
                TemplateItem(name: "Shake Shack", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1771639270/TierList_ShakeShack_hro5xf.png")!),
                TemplateItem(name: "Jollibee", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1771639271/TierList_Jollibee_hbptzw.png")!),
                TemplateItem(name: "Canes", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1771639417/TierList_Canes_l6d65c.jpg")!),
                TemplateItem(name: "In-N-Out", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1771639270/TierList_InNOut_hsyqsd.png")!)
            ]
        ),
        Template(
            name: "Streaming Services",
            category: "Entertainment",
            items: [
                TemplateItem(name: "Netflix", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1771639673/TierList_Netflix_ivv1jx.png")!),
                TemplateItem(name: "Disney+", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1771639672/TierList_Disney_n0xuwb.jpg")!),
                TemplateItem(name: "HBO Max", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1771639672/TierList_HBOMax_naetvr.jpg")!),
                TemplateItem(name: "Amazon Prime", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1771639671/TierList_PrimeVideo_x9hnnh.png")!),
                TemplateItem(name: "Apple TV+", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1771639671/TierList_AppleTV_dfrqsl.jpg")!),
                TemplateItem(name: "Hulu", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1771639672/TierList_Hulu_stvdxw.jpg")!),
                TemplateItem(name: "Paramount+", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1771639673/TierList_ParamountPlus_eekgan.png")!),
                TemplateItem(name: "Peacock", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1771639672/TierList_Peacock_ttzkju.png")!),
                TemplateItem(name: "YouTube TV", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1771639672/TierList_YoutubeTV_u3alz9.png")!),
                TemplateItem(name: "Crunchyroll", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1771639672/TierList_Crunchyroll_bmgknt.png")!)
            ]
        ),
        Template(
            name: "Cereals",
            category: "Food",
            items: [
                TemplateItem(name: "Fruity Pebbles", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1771639978/TierList_FruityPebbles_awvcsh.jpg")!),
                TemplateItem(name: "Cinnamon Toast Crunch", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1771639977/TierList_CTC_jp7ir9.webp")!),
                TemplateItem(name: "Lucky Charms", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1771639976/TierList_LuckyCharms_r4hfza.jpg")!),
                TemplateItem(name: "Froot Loops", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1771639976/TierList_FrootLoops_pktcp6.jpg")!),
                TemplateItem(name: "Trix", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1771639977/TierList_Trix_fyxcxc.jpg")!),
                TemplateItem(name: "Cocoa Puffs", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1771639977/TierList_CocoaPuffs_urghqa.jpg")!),
                TemplateItem(name: "Cap'n Crunch", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1771639977/TierList_CapnCrunch_lcx138.jpg")!),
                TemplateItem(name: "Honey Nut Cheerios", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1771639977/TierList_Cheerios_mcyqpi.jpg")!),
                TemplateItem(name: "Rice Krispies", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1771639977/TierList_RiceKrispies_ou0ln9.jpg")!),
                TemplateItem(name: "Frosted Flakes", imageURL: URL(string: "https://res.cloudinary.com/ddufg4gvq/image/upload/v1771639978/TierList_FrostedFlakes_us4y0l.jpg")!)
            ]
        )
    ]
}
