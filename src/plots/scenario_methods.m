function keys = scenario_methods(scenario)
%SCENARIO_METHODS シナリオで比較する手法キーを表示順に返す。
catalog = method_catalog();
keys = {catalog(strcmp({catalog.scenario}, scenario)).key};
end
