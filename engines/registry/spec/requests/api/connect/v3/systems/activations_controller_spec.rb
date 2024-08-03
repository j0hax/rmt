describe Api::Connect::V3::Systems::ActivationsController, type: :request do
  include_context 'auth header', :system, :login, :password
  include_context 'version header', 3

  describe '#activations' do
    let(:system) { FactoryBot.create(:system, :with_activated_product) }
    let(:headers) { auth_header.merge(version_header) }

    context 'without valid repository cache' do
      context 'without X-Instance-Data headers or hw_info' do
        it 'does not update InstanceVerification cache' do
          get '/connect/systems/activations', headers: headers
          data = JSON.parse(response.body)
          expect(data[0]['service']['url']).to match(%r{^plugin:/susecloud})
          expect(InstanceVerification).not_to receive(:update_cache)
        end
      end

      context 'with X-Instance-Data headers and bad metadata' do
        before { headers['X-Instance-Data'] = 'IMDS' }

        it 'does not update InstanceVerification cache' do
          allow(ZypperAuth).to receive(:verify_instance).and_call_original
          get '/connect/systems/activations', headers: headers
          expect(response.body).to include('Instance verification failed')
          expect(InstanceVerification).not_to receive(:update_cache)
        end
      end
    end

    context 'with repository cache valid' do
      let(:cache_name) { "repo/cache/127.0.0.1-#{system.login}-#{system.products.first.id}" }

      before do
        allow(File).to receive(:join).and_call_original
        allow(InstanceVerification).to receive(:update_cache)
        allow(ZypperAuth).to receive(:verify_instance).and_call_original
        headers['X-Instance-Data'] = 'IMDS'
      end

      it 'refreshes registry cache key only' do
        FileUtils.mkdir_p('repo/cache')
        FileUtils.touch(cache_name)
        expect(InstanceVerification).to receive(:update_cache).with('127.0.0.1', system.login, nil, registry: true)
        get '/connect/systems/activations', headers: headers
        FileUtils.rm_rf('repo/cache')
        data = JSON.parse(response.body)
        expect(data[0]['service']['url']).to match(%r{^plugin:/susecloud})
      end
    end
  end
end
