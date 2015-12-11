package dslContext

@Grab('org.slf4j:slf4j-simple:1.7.7')
import groovy.util.logging.Slf4j
import migration.clearcase.Vob

@Slf4j
class MigrationContext {
    List<Vob> vobs = []

    /**
     * Adds a Vob to the component for migration
     * @param name The name of the Vob
     * @param closure The configuration of the Vob
     */
    def void vob(String name, @DelegatesTo(VobContext) Closure closure) {
        log.debug('Entering vob().')
        def vobContext = new VobContext(name)
        def vobClosure = closure.rehydrate(vobContext, this, this)
        vobClosure.resolveStrategy = Closure.DELEGATE_ONLY
        vobClosure.run()
        vobs.add(vobContext.vob)
        log.info('Added Vob {}.', vobContext.vob.name)
        log.debug('Exiting vob().')
    }
}