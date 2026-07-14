//
//  OfficialServiceDirectory.swift
//  Horology Vault
//
//  Created by Angel Burgos on 7/14/26.
//

import Foundation

/// A single manufacturer's official service/support entry point — root domain only, no
/// phone numbers or street addresses. Those change often and third-party listings for them
/// are frequently stale or wrong, which is worse than not showing one at all for something
/// as high-stakes as where to send an expensive watch for service. The root domain is the
/// one piece of contact info stable and well-known enough to ship with confidence.
struct OfficialServiceContact: Identifiable {
    let id = UUID()
    let brand: String
    let name: String
    let website: String
    let notes: String
}

/// Bundled as a Swift literal rather than a JSON resource file in the app bundle — same
/// static, read-only, ships-with-the-app effect the monetization plan's Phase 7 calls for,
/// without hand-editing the Xcode project file to register a new bundle resource.
enum OfficialServiceDirectory {
    static let contacts: [OfficialServiceContact] = [
        OfficialServiceContact(
            brand: "Rolex",
            name: "Rolex Watch Care & Service",
            website: "rolex.com",
            notes: "Use the official service locator to find an authorized service center near you."
        ),
        OfficialServiceContact(
            brand: "Tudor",
            name: "TUDOR Care",
            website: "tudorwatch.com",
            notes: "Official retailers and service centers are listed under TUDOR Care on the brand's site."
        ),
        OfficialServiceContact(
            brand: "Omega",
            name: "OMEGA Customer Service",
            website: "omegawatches.com",
            notes: "The Customer Service section lists official service centers by region."
        ),
        OfficialServiceContact(
            brand: "Seiko",
            name: "Seiko Customer Service",
            website: "seikowatches.com",
            notes: "Regional service center listings are under Customer Service on the brand's site."
        ),
        OfficialServiceContact(
            brand: "TAG Heuer",
            name: "TAG Heuer Repair Center",
            website: "tagheuer.com",
            notes: "The Service section lists authorized repair centers and a contact form."
        ),
        OfficialServiceContact(
            brand: "Breitling",
            name: "Breitling Customer Service",
            website: "breitling.com",
            notes: "Official service and boutique locations are listed on the brand's site."
        ),
        OfficialServiceContact(
            brand: "IWC Schaffhausen",
            name: "IWC Client Service",
            website: "iwc.com",
            notes: "Official service centers and boutiques are listed under Client Service."
        ),
        OfficialServiceContact(
            brand: "Panerai",
            name: "Panerai Customer Care",
            website: "panerai.com",
            notes: "Official service centers are listed under Customer Care on the brand's site."
        ),
        OfficialServiceContact(
            brand: "Cartier",
            name: "Cartier Care & Service",
            website: "cartier.com",
            notes: "Official service and boutique locations are listed under Care & Service."
        ),
        OfficialServiceContact(
            brand: "Longines",
            name: "Longines Customer Service",
            website: "longines.com",
            notes: "Official service center listings are under Customer Service on the brand's site."
        ),
        OfficialServiceContact(
            brand: "Grand Seiko",
            name: "Grand Seiko Support",
            website: "grand-seiko.com",
            notes: "The Support section lists the authorized regional service network."
        ),
        OfficialServiceContact(
            brand: "Citizen",
            name: "Citizen Watch Support",
            website: "citizenwatch.com",
            notes: "The Support site lists service centers and repair-status tracking."
        ),
        OfficialServiceContact(
            brand: "Hamilton",
            name: "Hamilton Customer Service",
            website: "hamiltonwatch.com",
            notes: "The Customer Service section covers watch care and authorized repair centers."
        ),
        OfficialServiceContact(
            brand: "Casio",
            name: "Casio Watch Support",
            website: "casio.com",
            notes: "The Support section covers G-SHOCK and other watch lines, with an online repair portal."
        ),
        OfficialServiceContact(
            brand: "Hublot",
            name: "Hublot Customer Service",
            website: "hublot.com",
            notes: "Official service and boutique locations are listed on the brand's site."
        ),
        OfficialServiceContact(
            brand: "Tissot",
            name: "Tissot Customer Service",
            website: "tissotwatches.com",
            notes: "Official service center listings are under Customer Service on the brand's site."
        )
    ] + additionalContacts

    /// Independent/boutique and other enthusiast-collector brands (from a broader brand-name
    /// survey) — kept in a second array so the curated, well-known set above stays easy to
    /// scan on its own. Same rule as above: root domain only, verified via web search rather
    /// than guessed, no phone numbers/addresses. A handful of brands from that survey are
    /// deliberately omitted: Claude Meylan and Emmanuel Bouchet (no confident official site
    /// found), and Purnell (ceased operating/bankrupt as of December 2024, so there's no
    /// active support to point to).
    private static let additionalContacts: [OfficialServiceContact] = [
        contact("A. Lange & Söhne", "alange-soehne.com"),
        contact("Alpina", "alpinawatches.com"),
        contact("Anonimo", "anonimo.com"),
        contact("Armin Strom", "arminstrom.com"),
        contact("Arnold & Son", "arnoldandson.com"),
        contact("Audemars Piguet", "audemarspiguet.com"),
        contact("Baume & Mercier", "baume-et-mercier.com"),
        contact("Bell & Ross", "bellross.com"),
        contact("Blancpain", "blancpain.com"),
        contact("Breguet", "breguet.com"),
        contact("Bremont", "bremont.com"),
        contact("Bvlgari", "bulgari.com"),
        contact("Carl F. Bucherer", "carl-f-bucherer.com"),
        contact("Certina", "certina.com"),
        contact("Chanel", "chanel.com"),
        contact("Chopard", "chopard.com"),
        contact("Corum", "corum-watches.com"),
        contact("Doxa", "doxawatches.com"),
        contact("Ebel", "ebel.com"),
        contact("Fabergé", "faberge.com"),
        contact("Franck Muller", "franckmuller.com"),
        contact("Frederique Constant", "frederiqueconstant.com"),
        contact("Girard-Perregaux", "girard-perregaux.com"),
        contact("Glashütte Original", "glashuette-original.com"),
        contact("Graham", "graham1695.com"),
        contact("H. Moser & Cie", "h-moser.com"),
        contact("Hermès", "hermes.com"),
        contact("Jaeger-LeCoultre", "jaeger-lecoultre.com"),
        contact("Jaquet Droz", "jaquet-droz.com"),
        contact("Junghans", "junghans.de"),
        contact("Louis Vuitton", "louisvuitton.com"),
        contact("Luminox", "luminox.com"),
        contact("Maurice Lacroix", "mauricelacroix.com"),
        contact("MB&F", "mbandf.com"),
        contact("Montblanc", "montblanc.com"),
        contact("Movado", "movado.com"),
        contact("Nomos Glashütte", "nomos-glashuette.com"),
        contact("Oris", "oris.ch"),
        contact("Parmigiani Fleurier", "parmigiani.com"),
        contact("Patek Philippe", "patek.com"),
        contact("Perrelet", "perrelet.com"),
        contact("Piaget", "piaget.com"),
        contact("Rado", "rado.com"),
        contact("Ralph Lauren", "ralphlauren.com"),
        contact("Raymond Weil", "raymond-weil.com"),
        contact("Richard Mille", "richardmille.com"),
        contact("Roger Dubuis", "rogerdubuis.com"),
        contact("Ulysse Nardin", "ulysse-nardin.com"),
        contact("Vacheron Constantin", "vacheron-constantin.com"),
        contact("Van Cleef & Arpels", "vancleefarpels.com"),
        contact("Zenith", "zenith-watches.com"),
        contact("Zodiac", "zodiacwatches.com"),
        contact("AKRIVIA", "akrivia.com"),
        contact("Albishorn", "albishorn-watches.ch"),
        contact("Alexander Shorokhoff", "alexander-shorokhoff.com"),
        contact("Andreas Strehler", "astrehler.ch"),
        contact("Angelus", "angelus-watches.com"),
        contact("Armand Nicolet", "armandnicolet.com"),
        contact("Ateliers de Monaco", "ateliers-demonaco.com"),
        contact("Auguste Reymond", "augustereymond.ch"),
        contact("BA111OD", "ba111od.com"),
        contact("Backes & Strauss", "backesandstrauss.com"),
        contact("BALL", "ballwatch.com"),
        contact("Bausele", "bausele.com"),
        contact("BENRUS", "benrus.com"),
        contact("Bianchet", "bianchet.com"),
        contact("Bimbu", "bimbu.ch"),
        contact("Bomberg", "bombergwatches.com"),
        contact("Brellum", "brellum.swiss"),
        contact("Breva", "breva-watches.com"),
        contact("Briston", "briston-watches.com"),
        contact("Carl Suchy & Söhne", "carlsuchy.com"),
        contact("Century", "century.ch"),
        contact("Christophe Claret", "christopheclaret.cc"),
        contact("Chronoswiss", "chronoswiss.com"),
        contact("CODE41", "code41.com"),
        contact("Cuervo y Sobrinos", "cuervoysobrinos.com"),
        contact("Cvstos", "cvstos.com"),
        contact("Cyrus", "cyrus-watches.ch"),
        contact("Czapek", "czapek.com"),
        contact("Daniel Roth", "danielroth.com"),
        contact("David Candaux", "davidcandaux.com"),
        contact("De Bethune", "debethune.ch"),
        contact("De Rijke & Co.", "derijkeandco.com"),
        contact("Delbana", "delbana.ch"),
        contact("Delma", "delma.ch"),
        contact("Eberhard & Co", "eberhard-co-watches.ch"),
        contact("Emile Chouriet", "emilechouriet.com"),
        contact("F.P.Journe", "fpjourne.com"),
        contact("Favre Leuba", "favreleuba.com"),
        contact("Ferdinand Berthoud", "ferdinandberthoud.ch"),
        contact("Fiona Krüger", "fionakruger.com"),
        contact("Fortis", "fortis-swiss.com"),
        contact("Frederic Jouvenot", "fjouvenot.com"),
        contact("Furlan Marri", "furlanmarri.com"),
        contact("Gerald Genta", "geraldgenta.com"),
        contact("Gorilla", "gorilla-watches.com"),
        contact("GoS Watches", "goswatches.com"),
        contact("Greubel Forsey", "greubelforsey.com"),
        contact("Grönefeld", "gronefeld.com"),
        contact("Hanhart", "hanhart.com"),
        contact("HAUTLENCE", "hautlence.com"),
        contact("Hysek", "hysek.swiss"),
        contact("HYT", "hytwatches.com"),
        contact("Ikepod", "ikepod.com"),
        contact("Jacob & Co", "jacobandco.com"),
        contact("Klokers", "klokers.com"),
        contact("Krayon", "krayon.ch"),
        contact("L. Leroy", "montres-leroy.com"),
        contact("Laurent Ferrier", "laurentferrier.ch"),
        contact("Linde Werdelin", "lindewerdelin.com"),
        contact("Lorige", "lorige.com"),
        contact("Louis Erard", "louiserard.com"),
        contact("Louis Moinet", "louismoinet.com"),
        contact("Ludovic Ballouard", "ballouard.com"),
        contact("Lundis Bleus", "lundis-bleus.com"),
        contact("Mancheront", "mancheront.com"),
        contact("Manufacture Royale", "manufacture-royale.com"),
        contact("Marco Tedeschi", "marco-tedeschi.com"),
        contact("Massena LAB", "massenalab.com"),
        contact("Maurice de Mauriac", "mdm-watches.com"),
        contact("Mauron Musy", "mauronmusy.com"),
        contact("MeisterSinger", "meistersinger.com"),
        contact("Moritz Grossmann", "grossmann-uhren.com"),
        contact("Nivada Grenchen", "nivadagrenchenofficial.com"),
        contact("NORQAIN", "norqain.com"),
        contact("Oligo", "oligowatches.com"),
        contact("Pequignet", "pequignet.com"),
        contact("Praesidus", "praesidus.com"),
        contact("Raketa", "world.raketa.com"),
        contact("Reservoir", "reservoir-watch.com"),
        contact("Ressence", "ressencewatches.com"),
        contact("Riskers", "riskers-watches.com"),
        contact("Romain Gauthier", "romaingauthier.com"),
        contact("Schwarz Etienne", "schwarz-etienne.ch"),
        contact("SevenFriday", "sevenfriday.com"),
        contact("Singer Reimagined", "singerreimagined.com"),
        contact("Speake-Marin", "speake-marin.com"),
        contact("Squale", "squale.ch"),
        contact("TAOS", "taoswatches.com"),
        contact("Titoni", "titoni.ch"),
        contact("Trilobe", "trilobe.com"),
        contact("Tutima Glashütte", "tutima.com"),
        contact("U-Boat", "uboatwatch.com"),
        contact("Undone", "undone.com"),
        contact("Universal Genève", "universalgeneve.com"),
        contact("Urwerk", "urwerk.com"),
        contact("Venezianico", "venezianico.com"),
        contact("Voutilainen", "voutilainen.ch"),
        contact("Vulcain", "vulcain.ch"),
        contact("Zeitwinkel", "zeitwinkel.ch"),
        contact("ZRC", "zrc1904.com"),
        contact("STREHLER", "strehler.watch")
    ]

    private static func contact(_ brand: String, _ website: String) -> OfficialServiceContact {
        OfficialServiceContact(
            brand: brand,
            name: brand,
            website: website,
            notes: "Visit the official website for service and support information."
        )
    }
}
