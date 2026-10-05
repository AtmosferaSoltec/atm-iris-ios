//
//  MockServicePlanRepository.swift
//  iris
//

import Foundation

struct MockServicePlanRepository: ServicePlanRepository {
    var latency: Duration = .milliseconds(450)

    func currentService() async throws -> ServicePlan {
        try await Task.sleep(for: latency)
        return Self.sample
    }

    static var sample: ServicePlan {
        let samples = MockServicePlanRepository()
        return ServicePlan(
            id: UUID(),
            title: "Servicio dominical",
            date: Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: .now) ?? .now,
            items: [samples.welcome, samples.amazingGrace, samples.holyHolyHoly, samples.psalm23, samples.baptisms, samples.mightyFortress]
        )
    }

    // MARK: Sample content (public-domain texts)

    private var welcome: ServiceItem {
        ServiceItem(
            kind: .announcement,
            title: "Bienvenida",
            subtitle: "Anuncios de la semana",
            slides: [
                Slide(content: .text("Bienvenidos a casa", footnote: "Iglesia Vida Nueva")),
                Slide(content: .text("Cena congregacional\nSábado · 7:00 p. m.", footnote: "Salón principal"))
            ]
        )
    }

    private var amazingGrace: ServiceItem {
        ServiceItem(
            kind: .song,
            title: "Sublime gracia",
            subtitle: "John Newton",
            slides: [
                Slide(label: "Estrofa 1", content: .text("Sublime gracia del Señor\nque a un pecador salvó;\nfui ciego mas hoy veo yo,\nperdido y Él me halló.", footnote: nil)),
                Slide(label: "Estrofa 2", content: .text("Su gracia me enseñó a temer,\nmis dudas ahuyentó;\n¡oh cuán precioso fue a mi ser\ncuando Él me transformó!", footnote: nil)),
                Slide(label: "Estrofa 3", content: .text("En los peligros o aflicción\nque yo he tenido aquí,\nsu gracia siempre me libró\ny me guiará feliz.", footnote: nil)),
                Slide(label: "Estrofa 4", content: .text("Y cuando en Sion por siglos mil\nbrillando esté cual sol,\nyo cantaré por siempre allí\nsu amor que me salvó.", footnote: nil))
            ]
        )
    }

    private var holyHolyHoly: ServiceItem {
        ServiceItem(
            kind: .song,
            title: "Santo, santo, santo",
            subtitle: "Reginald Heber · trad. Juan B. Cabrera",
            slides: [
                Slide(label: "Estrofa 1", content: .text("¡Santo, santo, santo! Señor omnipotente,\nsiempre el labio mío loores te dará;\n¡Santo, santo, santo! te adoro reverente,\nDios en tres personas, bendita Trinidad.", footnote: nil)),
                Slide(label: "Estrofa 2", content: .text("¡Santo, santo, santo! en numeroso coro\nsantos escogidos te adoran sin cesar,\nde alegría llenos, y sus coronas de oro\nrinden ante el trono y el cristalino mar.", footnote: nil))
            ]
        )
    }

    private var psalm23: ServiceItem {
        ServiceItem(
            kind: .scripture,
            title: "Salmos 23:1-4",
            subtitle: "Reina-Valera 1909",
            slides: [
                Slide(label: "v. 1", content: .text("Jehová es mi pastor; nada me faltará.", footnote: "Salmos 23:1")),
                Slide(label: "v. 2", content: .text("En lugares de delicados pastos me hará yacer:\njunto a aguas de reposo me pastoreará.", footnote: "Salmos 23:2")),
                Slide(label: "v. 3", content: .text("Confortará mi alma;\nguiárame por sendas de justicia\npor amor de su nombre.", footnote: "Salmos 23:3")),
                Slide(label: "v. 4", content: .text("Aunque ande en valle de sombra de muerte,\nno temeré mal alguno;\nporque tú estarás conmigo.", footnote: "Salmos 23:4"))
            ]
        )
    }

    private var baptisms: ServiceItem {
        ServiceItem(
            kind: .video,
            title: "Testimonios de bautismo",
            subtitle: "Video · 2:45",
            slides: [
                Slide(label: "Video", content: .video(title: "Testimonios de bautismo", duration: "2:45"))
            ]
        )
    }

    private var mightyFortress: ServiceItem {
        ServiceItem(
            kind: .song,
            title: "Castillo fuerte",
            subtitle: "Martín Lutero · trad. Juan B. Cabrera",
            slides: [
                Slide(content: .text("Castillo fuerte es nuestro Dios,\ndefensa y buen escudo;\ncon su poder nos librará\nen este trance agudo.", footnote: nil)),
                Slide(content: .text("Con furia y con afán\nacósanos Satán;\npor armas deja ver\nastucia y gran poder;\ncual él no hay en la tierra.", footnote: nil))
            ]
        )
    }
}
