//
//  LearnHubContentTests.swift
//  Horology VaultTests
//
//  Created by Angel Burgos on 7/15/26.
//

import Testing
@testable import Horology_Vault

/// Guards the two invariants `LearnHubView`'s cross-link to a user's Vault depends on: stable,
/// unique topic identity, and `complicationName` values that can only ever exactly match
/// `Watch.commonComplications` — a typo in either would silently break navigation or cross-linking.
struct LearnHubContentTests {

    @Test("Every topic slug is unique")
    func topicSlugsAreUnique() {
        let slugs = LearnHubContent.topics.map(\.slug)
        #expect(Set(slugs).count == slugs.count)
    }

    @Test("Every complicationName exactly matches an entry in Watch.commonComplications")
    func complicationNamesMatchCommonComplications() {
        let topicComplicationNames = LearnHubContent.topics.compactMap(\.complicationName)
        for name in topicComplicationNames {
            #expect(Watch.commonComplications.contains(name))
        }
    }

    @Test("Every entry in Watch.commonComplications has a matching Learn Hub topic")
    func everyCommonComplicationHasATopic() {
        let topicComplicationNames = Set(LearnHubContent.topics.compactMap(\.complicationName))
        for complication in Watch.commonComplications {
            #expect(topicComplicationNames.contains(complication))
        }
    }
}
