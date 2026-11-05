"""Isolated release-policy/rollback tests; never contacts systemd or the VM.

The Windows runner represents the Unix current symlink with a text pointer.
Atomic artifact writes are real files in a temporary workspace directory.
"""
import contextlib
import copy
import importlib.util
import json
import os
import pathlib
import subprocess
import tempfile
import time
import unittest
from unittest import mock

ROOT = pathlib.Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('release_policy', ROOT / 'distribution/ubuntu/apply-release.py')
release = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(release)


class ReleasePolicyTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='release-test-', dir=ROOT / 'work')
        self.root = pathlib.Path(self.temp.name)
        self.temp_root = mock.patch.object(tempfile, 'tempdir', str(self.root))
        self.temp_root.start()
        self.client = {'version': 26, 'version_name': '1.6.0',
                       'archive': 'releases/game-1.6.0-26.zip', 'sha256': 'a' * 64}
        self.metadata = {'schema': 1, 'build': 26, 'version': '1.6.0',
                         'hashes': {name: 'b' * 64 for name in release.BASE_ARTIFACTS |
                                    {'public/' + self.client['archive'], 'server/toque-war.service', 'server/toque-war-favela.service'}}}

    def tearDown(self):
        self.temp_root.stop()
        self.temp.cleanup()

    def test_manifest_allows_only_exact_authenticated_artifacts(self):
        self.assertEqual(release.validate_artifacts(self.metadata, self.client), self.client['archive'])
        self.metadata['hashes'].pop('server/toque-war.service')
        release.validate_artifacts(self.metadata, self.client)
        self.metadata['hashes']['server/../../etc/cron.d/task'] = 'b' * 64
        with self.assertRaises(ValueError):
            release.validate_artifacts(self.metadata, self.client)

    def test_manifest_missing_bad_digest_version_and_archive(self):
        changes = [lambda a, b: a['hashes'].pop('public/api.php'),
                   lambda a, b: a['hashes'].__setitem__('public/api.php', 'BAD'),
                   lambda a, b: a.__setitem__('build', 27),
                   lambda a, b: a.__setitem__('version', 'different'),
                   lambda a, b: b.__setitem__('archive', '../release.zip'),
                   lambda a, b: b.__setitem__('sha256', 'not-a-digest'),
                   lambda a, b: b.__setitem__('version', True)]
        for change in changes:
            with self.subTest(change=change):
                metadata, client = copy.deepcopy(self.metadata), copy.deepcopy(self.client)
                change(metadata, client)
                with self.assertRaises(ValueError):
                    release.validate_artifacts(metadata, client)

    def test_actual_war_units_match_policy(self):
        release.validate_war_unit(ROOT / 'distribution/ubuntu/toque-war.service')
        release.validate_war_afghan_unit(ROOT / 'distribution/ubuntu/toque-war-afghan.service')
        release.validate_war_favela_unit(ROOT / 'distribution/ubuntu/toque-war-favela.service')

    def test_actual_br_unit_and_optional_signed_artifact(self):
        release.validate_br_unit(ROOT / 'distribution/ubuntu/toque-br.service')
        self.metadata['hashes']['server/toque-br.service'] = 'b' * 64
        release.validate_artifacts(self.metadata, self.client)
        original = (ROOT / 'distribution/ubuntu/toque-br.service').read_text(encoding='utf-8')
        for changed in (original.replace('User=toque-server', 'User=root'),
                        original.replace('--br-max-rooms=2', '--br-max-rooms=16'),
                        original.replace('MemoryMax=4G', 'MemoryMax=8G'),
                        original.replace('KillMode=control-group', 'KillMode=process'),
                        original.replace('Type=simple', 'Type=simple\nExecStartPre=/bin/sh')):
            path = self.root / 'br.service';path.write_text(changed)
            with self.assertRaises(ValueError):release.validate_br_unit(path)

    def test_br_players_and_live_child_guard_block_even_without_broker(self):
        path = self.status('br-broker-status.json', count=1)
        with mock.patch.object(release, 'GAME_DATA', self.root), mock.patch.object(release, 'active', side_effect=lambda unit: unit == 'toque-br'):
            with self.assertRaisesRegex(RuntimeError, 'jogadores conectados'):release.guard_players()
        path.unlink()
        room = self.root / 'br-matches' / ('a' * 32);room.mkdir(parents=True)
        (room / 'status.json').write_text(json.dumps({'pid':123456, 'humans':1, 'heartbeat':time.time()}))
        with mock.patch.object(release, 'GAME_DATA', self.root), mock.patch.object(release, 'active', return_value=False), mock.patch.object(release.os, 'kill', return_value=None), mock.patch.object(release, 'br_room_process_matches', return_value=True):
            with self.assertRaisesRegex(RuntimeError, 'jogadores conectados'):release.guard_players()
        with mock.patch.object(release, 'GAME_DATA', self.root), mock.patch.object(release, 'active', return_value=False), mock.patch.object(release.os, 'kill', side_effect=ProcessLookupError):
            release.guard_players()

    def test_br_stale_room_ignores_recycled_pid_but_not_real_room(self):
        room_id = 'b' * 32
        room = self.root / 'br-matches' / room_id;room.mkdir(parents=True)
        (room / 'status.json').write_text(json.dumps({
            'pid':123456, 'humans':0, 'heartbeat':time.time()-600,
            'phase':'cancelled', 'room_id':room_id
        }))
        common = [mock.patch.object(release, 'GAME_DATA', self.root),
                  mock.patch.object(release, 'active', return_value=False),
                  mock.patch.object(release.os, 'kill', return_value=None)]
        with common[0], common[1], common[2], mock.patch.object(release, 'br_room_process_matches', return_value=False) as matcher:
            release.guard_players()
            matcher.assert_called_once_with(123456, room_id)
        with mock.patch.object(release, 'GAME_DATA', self.root), mock.patch.object(release, 'active', return_value=False), mock.patch.object(release.os, 'kill', return_value=None), mock.patch.object(release, 'br_room_process_matches', return_value=True):
            with self.assertRaisesRegex(RuntimeError, 'Cannot confirm an empty BR room'):
                release.guard_players()

    def test_br_health_requires_new_heartbeat_and_broker_socket(self):
        path = self.status('br-broker-status.json')
        with mock.patch.object(release, 'GAME_DATA', self.root), mock.patch.object(release, 'active', return_value=True), mock.patch.object(release, 'run', return_value=subprocess.CompletedProcess([], 0, '5432\n', '')), mock.patch.object(release, 'process_owns_udp', return_value=True) as udp:
            release.services_healthy(['toque-br'], path.stat().st_mtime_ns - 1)
            udp.assert_called_once_with(5432, 3016)

    def test_unit_rejects_root_commands_duplicates_and_changed_paths(self):
        original = (ROOT / 'distribution/ubuntu/toque-war.service').read_text(encoding='utf-8')
        variants = [original.replace('User=toque-server', 'User=root'),
                    original.replace('Type=simple', 'Type=simple\nExecStartPre=/bin/sh -c evil'),
                    original.replace('ReadWritePaths=/var/lib/toque-de-campo/game', 'ReadWritePaths=/'),
                    original.replace('Restart=on-failure', 'Restart=on-failure\nRestart=always'),
                    original + '\n[Service]\nUser=root\n',
                    original.replace('--war-server', '--pvp-server'),
                    '#' * 16385]
        for value in variants:
            path = self.root / 'candidate.service'
            path.write_text(value, encoding='utf-8')
            with self.assertRaises(ValueError):
                release.validate_war_unit(path)

    def test_bounded_file_limits(self):
        path = self.root / 'bounded'
        path.write_bytes(b'x' * 30)
        self.assertEqual(release.read_bounded(path, 30), b'x' * 30)
        with self.assertRaises(ValueError):
            release.read_bounded(path, 29)

    def status(self, name, count=0, age=0):
        path = self.root / name
        path.write_text(json.dumps({'connections': count, 'updated': time.time() - age}), encoding='utf-8')
        return path

    def test_empty_servers_allow_guard_and_war_players_block(self):
        for name, _ in release.SERVICE_STATUS.values():
            self.status(name)
        with mock.patch.object(release, 'GAME_DATA', self.root), mock.patch.object(release, 'active', return_value=True):
            release.guard_players()
            self.status('war-status.json', count=1)
            with self.assertRaisesRegex(RuntimeError, 'jogadores conectados'):
                release.guard_players()

    def test_active_missing_stale_or_invalid_heartbeat_fails_closed(self):
        for value in (None, {'connections': 0, 'updated': time.time() - 60},
                      {'connections': -1, 'updated': time.time()},
                      {'connections': 0, 'updated': time.time() + 60},
                      {'connections': '0', 'updated': time.time()}):
            path = self.root / 'war-status.json'
            path.unlink(missing_ok=True)
            if value is not None:
                path.write_text(json.dumps(value))
            with mock.patch.object(release, 'GAME_DATA', self.root), mock.patch.object(release, 'active', side_effect=lambda unit: unit == 'toque-war'):
                with self.assertRaisesRegex(RuntimeError, 'Cannot confirm'):
                    release.guard_players()

    def test_inactive_old_status_does_not_block_initial_war_install(self):
        self.status('war-status.json', count=2, age=120)
        with mock.patch.object(release, 'GAME_DATA', self.root), mock.patch.object(release, 'active', return_value=False):
            release.guard_players()

    def test_health_requires_fresh_process_heartbeat_and_socket(self):
        path = self.status('war-status.json')
        started = path.stat().st_mtime_ns - 1
        with mock.patch.object(release, 'GAME_DATA', self.root), mock.patch.object(release, 'active', return_value=True), mock.patch.object(release, 'run', return_value=subprocess.CompletedProcess([], 0, '4321\n', '')), mock.patch.object(release, 'process_owns_udp', return_value=True) as udp:
            release.services_healthy(['toque-war'], started)
            udp.assert_called_once_with(4321, 3014)
            for owns, stamp in ((False, started), (True, started + 1000000)):
                with mock.patch.object(release, 'process_owns_udp', return_value=owns), mock.patch.object(release.time, 'monotonic', side_effect=[0, 0, 2]), mock.patch.object(release.time, 'sleep'):
                    with self.assertRaisesRegex(RuntimeError, 'health failed'):
                        release.services_healthy(['toque-war'], stamp, timeout=1)

    def test_favela_health_requires_dedicated_3017_socket(self):
        path = self.status('war-favela-status.json')
        started = path.stat().st_mtime_ns - 1
        with mock.patch.object(release, 'GAME_DATA', self.root), mock.patch.object(release, 'active', return_value=True), mock.patch.object(release, 'run', return_value=subprocess.CompletedProcess([], 0, '7331\n', '')), mock.patch.object(release, 'process_owns_udp', return_value=True) as udp:
            release.services_healthy(['toque-war-favela'], started)
            udp.assert_called_once_with(7331, 3017)

    @contextlib.contextmanager
    def activation(self, existing_war=False, enabled=False):
        stage, web, app = (self.root / name for name in ('stage', 'web', 'app'))
        war = self.root / 'systemd/toque-war.service'
        war.parent.mkdir()
        for path in (stage / 'server', stage / 'public/releases', web / 'accounts', web / 'releases', app / 'releases/build-25', app / 'releases/build-26'):
            path.mkdir(parents=True, exist_ok=True)
        current = app / 'current'
        current.write_text(str(app / 'releases/build-25'))
        for name in ('api.php', 'index.html', 'ToqueDeCampo.exe', 'manifest.json', self.client['archive']):
            (stage / 'public' / name).write_text('new:' + name)
        for name in ('index.html', 'ToqueDeCampo.exe', 'manifest.json'):
            (web / name).write_text('old:' + name)
        (web / 'accounts/api.php').write_text('old:api.php')
        (stage / 'server/toque-war.service').write_text('new-unit')
        if existing_war:
            war.write_text('old-unit')
        events = []
        def command(*args, check=True):
            events.append(args)
            return subprocess.CompletedProcess(args, 0, ('enabled' if enabled else 'not-found') if args[1] == 'is-enabled' else '', '')
        def pointer(target):
            current.write_text(str(target))
        original_symlink = pathlib.Path.is_symlink
        def is_symlink(path):
            return path.exists() if path == current else original_symlink(path)
        with mock.patch.object(release, 'APP', app), mock.patch.object(release, 'WEB', web), mock.patch.object(release, 'WAR_UNIT', war), mock.patch.object(release, 'active', side_effect=lambda unit: unit != 'toque-war' or existing_war), mock.patch.object(release, 'run', side_effect=command), mock.patch.object(release, 'guard_players'), mock.patch.object(release, 'services_healthy'), mock.patch.object(release, 'accounts_healthy'), mock.patch.object(release, 'replace_current', side_effect=pointer), mock.patch.object(pathlib.Path, 'is_symlink', is_symlink), mock.patch.object(release.os, 'readlink', side_effect=lambda path: pathlib.Path(path).read_text()):
            yield stage, web, app, war, events

    def assert_old_files(self, web, app):
        self.assertEqual((app / 'current').read_text(), str(app / 'releases/build-25'))
        self.assertEqual((web / 'accounts/api.php').read_text(), 'old:api.php')
        for name in ('index.html', 'ToqueDeCampo.exe', 'manifest.json'):
            self.assertEqual((web / name).read_text(), 'old:' + name)
        self.assertFalse((web / self.client['archive']).exists())

    def test_first_war_health_failure_restores_old_game_api_and_absent_unit(self):
        with self.activation() as (stage, web, app, war, events):
            release.services_healthy.side_effect = RuntimeError('war failed')
            with self.assertRaisesRegex(RuntimeError, 'war failed'):
                release.activate(stage, self.client, self.client['archive'], app / 'releases/build-26')
            self.assert_old_files(web, app)
            self.assertFalse(war.exists())
            restarts = [event for event in events if event[:2] == ('systemctl', 'restart')]
            self.assertIn('toque-war', restarts[0])
            self.assertEqual(restarts[-1], ('systemctl', 'restart', 'toque-naval', 'toque-pvp'))

    def test_existing_war_unit_enabled_state_and_services_are_restored(self):
        with self.activation(existing_war=True, enabled=True) as (stage, web, app, war, events):
            release.accounts_healthy.side_effect = RuntimeError('accounts failed')
            with self.assertRaises(RuntimeError):
                release.activate(stage, self.client, self.client['archive'], app / 'releases/build-26')
            self.assert_old_files(web, app)
            self.assertEqual(war.read_text(), 'old-unit')
            self.assertEqual([event for event in events if event[:2] == ('systemctl', 'restart')][-1], ('systemctl', 'restart', 'toque-naval', 'toque-pvp', 'toque-war'))
            self.assertIn(('systemctl', 'enable', 'toque-war'), events)

    def test_partial_publication_failure_restores_downloads_and_manifest(self):
        with self.activation() as (stage, web, app, war, events):
            original = release.atomic_copy
            def copy_file(source, destination, mode=0o644):
                if source == stage / 'public/index.html':
                    raise OSError('disk failure')
                return original(source, destination, mode)
            with mock.patch.object(release, 'atomic_copy', side_effect=copy_file):
                with self.assertRaisesRegex(OSError, 'disk failure'):
                    release.activate(stage, self.client, self.client['archive'], app / 'releases/build-26')
            self.assert_old_files(web, app)
            self.assertFalse(war.exists())

    def test_enable_failure_after_manifest_commit_rolls_back_everything(self):
        with self.activation() as (stage, web, app, war, events):
            previous = release.run.side_effect
            def command(*args, check=True):
                if args == ('systemctl', 'enable', 'toque-war'):
                    raise subprocess.CalledProcessError(1, args)
                return previous(*args, check=check)
            release.run.side_effect = command
            with self.assertRaises(subprocess.CalledProcessError):
                release.activate(stage, self.client, self.client['archive'], app / 'releases/build-26')
            self.assert_old_files(web, app)
            self.assertFalse(war.exists())

    def test_success_publishes_manifest_after_downloads_and_enables_war(self):
        with self.activation() as (stage, web, app, war, events):
            original, copied = release.atomic_copy, []
            def copy_file(source, destination, mode=0o644):
                copied.append(destination)
                return original(source, destination, mode)
            with mock.patch.object(release, 'atomic_copy', side_effect=copy_file):
                release.activate(stage, self.client, self.client['archive'], app / 'releases/build-26')
            self.assertEqual(copied[-1], web / 'manifest.json')
            self.assertEqual((web / self.client['archive']).read_text(), 'new:' + self.client['archive'])
            self.assertEqual((web / 'accounts/api.php').read_text(), 'new:api.php')
            self.assertEqual((app / 'current').read_text(), str(app / 'releases/build-26'))
            self.assertEqual(war.read_text(), 'new-unit')
            self.assertEqual(events[-1], ('systemctl', 'enable', 'toque-war'))

    def test_favela_activation_starts_and_enables_service(self):
        with self.activation() as (stage, web, app, war, events):
            favela = war.with_name('toque-war-favela.service')
            (stage / 'server/toque-war-favela.service').write_text('new-favela-unit')
            with mock.patch.object(release, 'WAR_FAVELA_UNIT', favela):
                release.activate(stage, self.client, self.client['archive'], app / 'releases/build-26')
            self.assertEqual(favela.read_text(), 'new-favela-unit')
            self.assertIn(('systemctl', 'restart', 'toque-naval', 'toque-pvp', 'toque-war', 'toque-war-favela'), events)
            self.assertEqual(events[-1], ('systemctl', 'enable', 'toque-war-favela'))

    def test_initial_favela_health_failure_removes_unit_and_rolls_back(self):
        with self.activation() as (stage, web, app, war, events):
            favela = war.with_name('toque-war-favela.service')
            (stage / 'server/toque-war-favela.service').write_text('new-favela-unit')
            release.services_healthy.side_effect = RuntimeError('favela health failed')
            previous = release.active.side_effect
            with mock.patch.object(release, 'WAR_FAVELA_UNIT', favela), mock.patch.object(release, 'active', side_effect=lambda unit: False if unit == 'toque-war-favela' else previous(unit)):
                with self.assertRaisesRegex(RuntimeError, 'favela health failed'):
                    release.activate(stage, self.client, self.client['archive'], app / 'releases/build-26')
            self.assert_old_files(web, app)
            self.assertFalse(favela.exists())
            self.assertIn(('systemctl', 'disable', 'toque-war-favela'), events)
            self.assertEqual([event for event in events if event[:2] == ('systemctl', 'restart')][-1], ('systemctl', 'restart', 'toque-naval', 'toque-pvp'))

    def test_br_activation_starts_and_enables_broker(self):
        with self.activation() as (stage, web, app, war, events):
            br = war.with_name('toque-br.service')
            (stage / 'server/toque-br.service').write_text('new-br-unit')
            with mock.patch.object(release, 'BR_UNIT', br):
                release.activate(stage, self.client, self.client['archive'], app / 'releases/build-26')
            self.assertEqual(br.read_text(), 'new-br-unit')
            self.assertIn(('systemctl', 'restart', 'toque-naval', 'toque-pvp', 'toque-war', 'toque-br'), events)
            self.assertEqual(events[-1], ('systemctl', 'enable', 'toque-br'))

    def test_initial_br_health_failure_removes_unit_and_rolls_back(self):
        with self.activation() as (stage, web, app, war, events):
            br = war.with_name('toque-br.service')
            (stage / 'server/toque-br.service').write_text('new-br-unit')
            release.services_healthy.side_effect = RuntimeError('broker health failed')
            previous = release.active.side_effect
            with mock.patch.object(release, 'BR_UNIT', br), mock.patch.object(release, 'active', side_effect=lambda unit: False if unit == 'toque-br' else previous(unit)):
                with self.assertRaisesRegex(RuntimeError, 'broker health failed'):
                    release.activate(stage, self.client, self.client['archive'], app / 'releases/build-26')
            self.assert_old_files(web, app)
            self.assertFalse(br.exists())
            self.assertIn(('systemctl', 'disable', 'toque-br'), events)
            self.assertEqual([event for event in events if event[:2] == ('systemctl', 'restart')][-1], ('systemctl', 'restart', 'toque-naval', 'toque-pvp'))

    def test_existing_br_rollback_restores_unit_enabled_state_and_service(self):
        with self.activation(existing_war=True, enabled=True) as (stage, web, app, war, events):
            br = war.with_name('toque-br.service');br.write_text('old-br-unit')
            (stage / 'server/toque-br.service').write_text('new-br-unit')
            release.accounts_healthy.side_effect = RuntimeError('accounts failed')
            with mock.patch.object(release, 'BR_UNIT', br):
                with self.assertRaisesRegex(RuntimeError, 'accounts failed'):
                    release.activate(stage, self.client, self.client['archive'], app / 'releases/build-26')
            self.assertEqual(br.read_text(), 'old-br-unit')
            self.assertIn(('systemctl', 'enable', 'toque-br'), events)
            self.assertIn('toque-br', [event for event in events if event[:2] == ('systemctl', 'restart')][-1])


if __name__ == '__main__':
    unittest.main(verbosity=2)
