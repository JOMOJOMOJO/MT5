import pytest

from .test_timing import setup as timing_setup
from .test_exits import setup as exits_setup
from tools.entry_research.diagnostics.timing import evaluate_timing
from tools.entry_research.diagnostics.exits import barrier_scenarios


@pytest.mark.parametrize('setup,evaluate', [(timing_setup,evaluate_timing),(exits_setup,barrier_scenarios)])
@pytest.mark.parametrize('violation', ['period','bars'])
def test_direct_api_cannot_read_2026(setup,evaluate,violation):
    bars,candidates,config=setup()
    if violation=='period':
        config['end_exclusive']=1767225601
    else:
        bars.loc[bars.index[-1],'time']=1767225600
    with pytest.raises(ValueError,match='2026 holdout'):
        evaluate(bars,candidates,config)
