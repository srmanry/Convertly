/// Every piece of text the app shows, as a key.
///
/// Constants rather than bare strings at the call sites: a typo here fails to
/// compile, while a typo in a quoted key would only show up as the raw key on
/// screen, in one language, on one screen, long after the change.
///
/// Placeholders are written `@name` and filled with `trParams`.
abstract final class K {
  // Bottom navigation and page titles.
  static const String navHome = 'nav_home';
  static const String navFiles = 'nav_files';
  static const String navPlayer = 'nav_player';
  static const String navSettings = 'nav_settings';

  // Words used on more than one screen.
  static const String cancel = 'common_cancel';
  static const String delete = 'common_delete';
  static const String deleteAll = 'common_delete_all';
  static const String save = 'common_save';
  static const String share = 'common_share';
  static const String play = 'common_play';
  static const String stop = 'common_stop';
  static const String preview = 'common_preview';
  static const String rename = 'common_rename';
  static const String remove = 'common_remove';
  static const String reset = 'common_reset';
  static const String done = 'common_done';
  static const String back = 'common_back';
  static const String goBack = 'common_go_back';
  static const String tryAgain = 'common_try_again';
  static const String refresh = 'common_refresh';
  static const String next = 'common_next';
  static const String skip = 'common_skip';
  static const String allow = 'common_allow';
  static const String search = 'common_search';
  static const String clearSearch = 'common_clear_search';
  static const String selectAll = 'common_select_all';
  static const String clearAll = 'common_clear_all';
  static const String saveToPhone = 'common_save_to_phone';
  static const String labelFile = 'common_label_file';
  static const String labelSize = 'common_label_size';
  static const String labelDuration = 'common_label_duration';
  static const String labelFormat = 'common_label_format';
  static const String labelName = 'common_label_name';
  static const String audio = 'common_audio';

  // Tools, named the same way wherever they appear.
  static const String toolVideoToAudio = 'tool_video_to_audio';
  static const String toolVideoToAudioDesc = 'tool_video_to_audio_desc';
  static const String toolAudioConvert = 'tool_audio_convert';
  static const String toolAudioConvertDesc = 'tool_audio_convert_desc';
  static const String toolCut = 'tool_cut';
  static const String toolCutDesc = 'tool_cut_desc';
  static const String toolMerge = 'tool_merge';
  static const String toolMergeDesc = 'tool_merge_desc';
  static const String toolCompress = 'tool_compress';
  static const String toolCompressDesc = 'tool_compress_desc';
  static const String toolMix = 'tool_mix';
  static const String toolMixDesc = 'tool_mix_desc';
  static const String toolArrange = 'tool_arrange';
  static const String toolArrangeDesc = 'tool_arrange_desc';
  static const String toolCleanup = 'tool_cleanup';
  static const String toolCleanupDesc = 'tool_cleanup_desc';
  static const String toolsSection = 'tools_section';

  // What each tool asks for.
  static const String selectVideo = 'action_select_video';
  static const String selectAudio = 'action_select_audio';
  static const String addAudioFiles = 'action_add_audio_files';

  // The button that starts each tool's work.
  static const String actionExtractAudio = 'action_extract_audio';
  static const String actionConvert = 'action_convert';
  static const String actionCutAudio = 'action_cut_audio';
  static const String actionMergeFiles = 'action_merge_files';
  static const String actionCompress = 'action_compress';
  static const String actionMixTracks = 'action_mix_tracks';
  static const String actionBuildTrack = 'action_build_track';
  static const String actionRemoveNoise = 'action_remove_noise';

  // Home.
  static const String greetingMorning = 'home_greeting_morning';
  static const String greetingAfternoon = 'home_greeting_afternoon';
  static const String greetingEvening = 'home_greeting_evening';
  static const String recentFiles = 'home_recent_files';
  static const String noFilesYet = 'home_no_files_yet';
  static const String noFilesYetMessage = 'home_no_files_yet_message';
  static const String seeAllFiles = 'home_see_all_files';
  static const String moreInLibrary = 'home_more_in_library';

  // Files.
  static const String myFiles = 'files_title';
  static const String searchFiles = 'files_search';
  static const String closeSearch = 'files_close_search';
  static const String sortFiles = 'files_sort';
  static const String cancelSelection = 'files_cancel_selection';
  static const String deleteSelected = 'files_delete_selected';
  static const String couldNotLoadFiles = 'files_could_not_load';
  static const String noMatchingFiles = 'files_no_matches';
  static const String nothingCalled = 'files_nothing_called';
  static const String savedToPhoneMessage = 'files_saved_to_phone';
  static const String couldNotSaveToPhone = 'files_could_not_save';
  static const String deleteFileTitle = 'files_delete_one_title';
  static const String deleteFilesTitle = 'files_delete_many_title';
  static const String deleteFileMessage = 'files_delete_one_message';
  static const String deleteFilesMessage = 'files_delete_many_message';
  static const String fileDeleted = 'files_deleted';
  static const String renameFile = 'files_rename_title';
  static const String renameHint = 'files_rename_hint';
  static const String fileNameLabel = 'files_name_label';
  static const String sortNewest = 'files_sort_newest';
  static const String sortOldest = 'files_sort_oldest';
  static const String sortName = 'files_sort_name';
  static const String sortSize = 'files_sort_size';

  // Player and music library.
  static const String nowPlaying = 'player_now_playing';
  static const String cannotPlayFile = 'player_cannot_play';
  static const String previousTrack = 'player_previous';
  static const String backTenSeconds = 'player_back_ten';
  static const String forwardTenSeconds = 'player_forward_ten';
  static const String nextTrack = 'player_next';
  static const String trackOf = 'player_track_of';
  static const String unknownTrack = 'player_unknown_track';
  static const String sourcePhone = 'library_source_phone';
  static const String sourceInApp = 'library_source_in_app';
  static const String musicPermissionTitle = 'library_permission_title';
  static const String musicPermissionMessage = 'library_permission_message';
  static const String nothingMatchesThat = 'library_nothing_matches';
  static const String noMusicYet = 'library_no_music_yet';
  static const String tryDifferentWord = 'library_try_another_word';
  static const String noSongsFound = 'library_no_songs_found';
  static const String convertedWillShowUp = 'library_converted_show_up';

  // Converter screens.
  static const String conversionFailed = 'converter_failed';
  static const String backToHome = 'converter_back_home';
  static const String addMoreFiles = 'converter_add_more_files';
  static const String chooseASource = 'converter_choose_source';
  static const String uploadingFile = 'converter_uploading';
  static const String addFromPhone = 'converter_add_from_phone';
  static const String phoneFiles = 'converter_phone_files';
  static const String addFromApp = 'converter_add_from_app';
  static const String appFiles = 'converter_app_files';
  static const String selectFromAppFiles = 'converter_pick_title';
  static const String pickTapOrSelectAll = 'converter_pick_multi_hint';
  static const String pickOneFile = 'converter_pick_single_hint';
  static const String searchAppFiles = 'converter_pick_search';
  static const String noSavedAudio = 'converter_pick_empty';
  static const String noAudioMatchesSearch = 'converter_pick_no_matches';
  static const String selectFiles = 'converter_pick_cta_many';
  static const String selectAFile = 'converter_pick_cta_one';
  static const String addNFiles = 'converter_pick_add_many';
  static const String addSelectedFile = 'converter_pick_add_one';
  static const String converting = 'converter_progress_title';
  static const String keepAppOpen = 'converter_progress_message';
  static const String playbackSpeed = 'converter_playback_speed';
  static const String startLabel = 'converter_start';
  static const String mixingSection = 'converter_mixing_section';
  static const String repeatLayers = 'converter_repeat_layers';
  static const String repeatLayersDesc = 'converter_repeat_layers_desc';
  static const String adjustVolumeOverTime = 'converter_volume_intro';
  static const String clipNumber = 'converter_clip_number';
  static const String mainTrack = 'converter_main_track';
  static const String layerNumber = 'converter_layer_number';
  static const String selectionLabel = 'converter_selection';
  static const String startsAt = 'converter_starts_at';
  static const String playsAt = 'converter_plays_at';
  static const String resetToHundred = 'converter_reset_volume';
  static const String baseLevel = 'converter_base_level';
  static const String trimSelection = 'converter_trim_selection';
  static const String selectionStart = 'converter_selection_start';
  static const String selectionEnd = 'converter_selection_end';
  static const String quieter = 'converter_quieter';
  static const String louder = 'converter_louder';
  static const String deletePoint = 'converter_delete_point';
  static const String volumeLaneHint = 'converter_volume_hint';
  static const String volumeMaxPoints = 'converter_volume_max_points';
  static const String volumeLaneAdjust = 'converter_volume_adjust_hint';
  static const String removeSection = 'converter_remove_section';
  static const String strengthSection = 'converter_strength_section';
  static const String outputFormatSection = 'converter_output_format';
  static const String qualitySection = 'converter_quality';
  static const String targetQualitySection = 'converter_target_quality';
  static const String fileNameSection = 'converter_file_name';
  static const String outputFileNameHint = 'converter_output_file_hint';
  static const String contactSection = 'privacy_contact';

  // Mixer and timeline detail.
  static const String orDivider = 'converter_or';
  static const String endLabel = 'converter_end';
  static const String stopAfter = 'converter_stop_after';
  static const String lengthFollowsMain = 'converter_length_follows_main';
  static const String previewAll = 'converter_preview_all';
  static const String previewAllHint = 'converter_preview_all_hint';
  static const String previewBalanceNote = 'converter_preview_balance_note';
  static const String timelineSection = 'converter_timeline_section';
  static const String timelineTotalUnknown = 'converter_timeline_total_unknown';
  static const String timelineTotal = 'converter_timeline_total';
  static const String timelineOrderNote = 'converter_timeline_order_note';
  static const String previewTheTrack = 'converter_preview_track';
  static const String previewTrackHint = 'converter_preview_track_hint';

  // Result screen.
  static const String conversionComplete = 'result_title';
  static const String playAudio = 'result_play_audio';
  static const String openFiles = 'result_open_files';
  static const String fileNoLongerAvailable = 'result_file_gone';

  // Settings.
  static const String settingsConversion = 'settings_section_conversion';
  static const String defaultOutputFormat = 'settings_default_format';
  static const String defaultAudioQuality = 'settings_default_quality';
  static const String settingsApp = 'settings_section_app';
  static const String settingsAds = 'settings_section_ads';
  static const String privacyPolicy = 'settings_privacy_policy';
  static const String adPrivacySettings = 'settings_ad_privacy';
  static const String language = 'settings_language';
  static const String chooseLanguage = 'settings_choose_language';
  static const String languageSystemDefault = 'settings_language_system';

  // Storage.
  static const String storageInformation = 'storage_title';
  static const String storageByFormat = 'storage_by_format';
  static const String storageUsedByApp = 'storage_used_by_app';
  static const String storageWorkingFiles = 'storage_working_files';
  static const String storageWorkingFilesDesc = 'storage_working_files_desc';
  static const String storageRemoveWorking = 'storage_remove_working';
  static const String storageConvertedFiles = 'storage_converted_files';
  static const String storageConvertedDesc = 'storage_converted_desc';
  static const String storageDeleteAllConverted = 'storage_delete_all';
  static const String storageDeleteAllTitle = 'storage_delete_all_title';
  static const String storageDeleteAllMessage = 'storage_delete_all_message';
  static const String storageSavedIn = 'storage_saved_in';
  static const String storageDeleteAllFreeing = 'storage_delete_all_freeing';
  static const String storageWorkingRemoved = 'storage_working_removed';
  static const String storageNoWorkingFiles = 'storage_no_working_files';
  static const String storageAllDeleted = 'storage_all_deleted';
  static const String storageSomeKept = 'storage_some_kept';

  // Ads.
  static const String adBreakOffer = 'ads_break_offer';
  static const String adBreakActive = 'ads_break_active';
  static const String adBreakStartHint = 'ads_break_start_hint';
  static const String adBreakProgressHint = 'ads_break_progress_hint';
  static const String adBreakExtendHint = 'ads_break_extend_hint';
  static const String adBreakEarned = 'ads_break_earned';
  static const String adBreakOneMore = 'ads_break_one_more';
  static const String adNoVideoReady = 'ads_no_video_ready';
  static const String adVideoMustFinish = 'ads_video_must_finish';
  static const String adMinutes = 'ads_minutes';
  static const String adUnderAMinute = 'ads_under_a_minute';
  static const String adWatchShortVideo = 'ads_watch_short_video';
  static const String adRewardPromptMessage = 'ads_reward_prompt_message';
  static const String adNoThanks = 'ads_no_thanks';
  static const String adWatchVideo = 'ads_watch_video';
  static const String adWatchForFiles = 'ads_watch_for_files';
  static const String adNoAdsThisFile = 'ads_none_this_file';
  static const String adNoAdsNextFile = 'ads_none_next_file';
  static const String adNoAdsNextFiles = 'ads_none_next_files';

  // Onboarding.
  static const String onboardingConvertTitle = 'onboarding_convert_title';
  static const String onboardingConvertBody = 'onboarding_convert_body';
  static const String onboardingOfflineTitle = 'onboarding_offline_title';
  static const String onboardingOfflineBody = 'onboarding_offline_body';
  static const String onboardingManageTitle = 'onboarding_manage_title';
  static const String onboardingManageBody = 'onboarding_manage_body';
  static const String getStarted = 'onboarding_get_started';

  // Option labels inside the tools.
  static const String noiseLight = 'noise_light';
  static const String noiseMedium = 'noise_medium';
  static const String noiseStrong = 'noise_strong';
  static const String mixLengthMain = 'mix_length_main';
  static const String mixLengthLongest = 'mix_length_longest';
  static const String cleanupNoiseTitle = 'cleanup_noise_title';
  static const String cleanupNoiseDesc = 'cleanup_noise_desc';
  static const String cleanupVoiceTitle = 'cleanup_voice_title';
  static const String cleanupVoiceDesc = 'cleanup_voice_desc';
  static const String cleanupVocalsTitle = 'cleanup_vocals_title';
  static const String cleanupVocalsDesc = 'cleanup_vocals_desc';
  static const String compressionHigh = 'compression_high';
  static const String compressionMedium = 'compression_medium';
  static const String compressionLow = 'compression_low';

  // Anything that went wrong.
  static const String errorCache = 'error_cache';
  static const String errorPermission = 'error_permission';
  static const String errorUnsupportedFile = 'error_unsupported_file';
  static const String errorStorage = 'error_storage';
  static const String errorConversion = 'error_conversion';
  static const String errorCancelled = 'error_cancelled';
  static const String errorUnknown = 'error_unknown';
  static const String errorNoFilesReadable = 'error_no_files_readable';
  static const String errorFileGone = 'error_file_gone';
  static const String errorFileUnreadable = 'error_file_unreadable';
  static const String errorNoAudioInFile = 'error_no_audio_in_file';
  static const String errorFileEmpty = 'error_file_empty';
  static const String errorFileTooLarge = 'error_file_too_large';
  static const String errorFileNotOpened = 'error_file_not_opened';
  static const String errorNotMedia = 'error_not_media';
  static const String errorNoAudioTrack = 'error_no_audio_track';
  static const String errorNotVideo = 'error_not_video';
  static const String errorConversionNotStarted = 'error_conversion_not_started';
  static const String errorNoFreeSpace = 'error_no_free_space';
  static const String errorOutputMissing = 'error_output_missing';
  static const String errorOutputEmpty = 'error_output_empty';
  static const String errorUnableToRead = 'error_unable_to_read';
  static const String errorInvalidFileName = 'error_invalid_file_name';
  static const String errorSectionTooShort = 'error_section_too_short';
  static const String errorNeedTwoTracks = 'error_need_two_tracks';
  static const String errorMonoNoCentre = 'error_mono_no_centre';
  static const String errorNoSaveLocation = 'error_no_save_location';
  static const String errorAddClipFirst = 'error_add_clip_first';
  static const String errorClipsNotPlayed = 'error_clips_not_played';
  static const String errorAddTrackFirst = 'error_add_track_first';
  static const String errorTracksNotPlayed = 'error_tracks_not_played';
  static const String errorSectionNotPlayed = 'error_section_not_played';
  static const String errorFilesNotLoaded = 'error_files_not_loaded';
  static const String errorFileNotSaved = 'error_file_not_saved';
  static const String errorFileNotRenamed = 'error_file_not_renamed';
  static const String errorFileNotDeleted = 'error_file_not_deleted';
  static const String errorFilesNotDeleted = 'error_files_not_deleted';
  static const String errorSettingsNotLoaded = 'error_settings_not_loaded';
  static const String errorSettingsNotSaved = 'error_settings_not_saved';
  static const String errorStorageNotRead = 'error_storage_not_read';
  static const String errorWorkingNotRemoved = 'error_working_not_removed';
  static const String errorMusicNotRead = 'error_music_not_read';
  static const String errorProgressNotSaved = 'error_progress_not_saved';
  static const String errorPlaybackFailed = 'error_playback_failed';
}
